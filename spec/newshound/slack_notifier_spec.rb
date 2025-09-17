# frozen_string_literal: true

RSpec.describe Newshound::SlackNotifier do
  let(:configuration) { double("configuration", valid?: true, slack_webhook_url: nil, slack_channel: "#test") }
  let(:logger) { double("logger") }
  let(:webhook_client) { double("webhook_client") }
  let(:web_api_client) { double("web_api_client") }

  subject(:notifier) do
    described_class.new(
      configuration: configuration,
      logger: logger,
      webhook_client: webhook_client,
      web_api_client: web_api_client
    )
  end

  describe "#post" do
    let(:message) { { blocks: ["test block"], text: "test" } }

    context "when configuration is invalid" do
      before { allow(configuration).to receive(:valid?).and_return(false) }

      it "does not send notification" do
        expect(webhook_client).not_to receive(:post)
        expect(web_api_client).not_to receive(:chat_postMessage)
        notifier.post(message)
      end
    end

    context "when webhook is configured" do
      before { allow(configuration).to receive(:slack_webhook_url).and_return("https://hooks.slack.com/test") }

      it "sends notification via webhook" do
        expect(webhook_client).to receive(:post).with(message)
        notifier.post(message)
      end
    end

    context "when web API is configured" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return(nil)
        allow(ENV).to receive(:[]).with("SLACK_API_TOKEN").and_return("token")
      end

      it "sends notification via web API" do
        expect(web_api_client).to receive(:chat_postMessage).with(
          channel: "#test",
          blocks: ["test block"],
          text: "Daily Newshound Report"
        )
        notifier.post(message)
      end
    end

    context "when no Slack method is configured" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return(nil)
        allow(ENV).to receive(:[]).with("SLACK_API_TOKEN").and_return(nil)
      end

      it "logs an error" do
        expect(logger).to receive(:error).with("Newshound: No valid Slack configuration found")
        notifier.post(message)
      end
    end

    context "when an exception occurs" do
      before do
        allow(configuration).to receive(:slack_webhook_url).and_return("https://hooks.slack.com/test")
        allow(webhook_client).to receive(:post).and_raise(StandardError, "Connection failed")
      end

      it "logs the error" do
        expect(logger).to receive(:error).with("Newshound: Failed to send Slack notification: Connection failed")
        notifier.post(message)
      end
    end
  end
end