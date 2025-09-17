# frozen_string_literal: true

require "spec_helper"
require "newshound/transport/slack"

RSpec.describe Newshound::Transport::Slack do
  let(:configuration) do
    double("Configuration",
           slack_webhook_url: "https://hooks.slack.com/test",
           slack_channel: "#general",
           valid?: true)
  end
  let(:logger) { double("Logger", error: nil, info: nil) }
  let(:webhook_client) { double("WebhookClient") }
  let(:web_api_client) { double("WebApiClient") }
  let(:transport) do
    described_class.new(
      configuration: configuration,
      logger: logger,
      webhook_client: webhook_client,
      web_api_client: web_api_client
    )
  end

  describe "#deliver" do
    let(:message) { { text: "Test message", blocks: [] } }

    context "when configuration is invalid" do
      before do
        allow(configuration).to receive(:valid?).and_return(false)
      end

      it "returns false without sending" do
        expect(webhook_client).not_to receive(:post)
        expect(transport.deliver(message)).to be_falsey
      end
    end

    context "when webhook is configured" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return("https://hooks.slack.com/test")
      end

      it "delivers via webhook" do
        expect(webhook_client).to receive(:post).with(message)
        expect(transport.deliver(message)).to eq(true)
      end

      context "when delivery fails" do
        it "logs error and returns false" do
          error = StandardError.new("Connection failed")
          allow(webhook_client).to receive(:post).and_raise(error)
          expect(logger).to receive(:error).with("Newshound: Failed to send Slack notification: Connection failed")
          expect(transport.deliver(message)).to eq(false)
        end
      end
    end

    context "when web API is configured" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return(nil)
        allow(ENV).to receive(:[]).with("SLACK_API_TOKEN").and_return("xoxb-test-token")
      end

      it "delivers via web API" do
        expect(web_api_client).to receive(:chat_postMessage).with(
          channel: "#general",
          blocks: [],
          text: "Daily Newshound Report"
        )
        expect(transport.deliver(message)).to eq(true)
      end
    end

    context "when no configuration exists" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return(nil)
        allow(ENV).to receive(:[]).with("SLACK_API_TOKEN").and_return(nil)
      end

      it "logs error and returns false" do
        expect(logger).to receive(:error).with("Newshound: No valid Slack configuration found")
        expect(transport.deliver(message)).to eq(false)
      end
    end
  end
end