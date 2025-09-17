# frozen_string_literal: true

require "spec_helper"

begin
  require "aws-sdk-sns"
  require "newshound/transport/sns"

  RSpec.describe Newshound::Transport::Sns do
  let(:configuration) do
    double("Configuration",
           sns_topic_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic",
           aws_region: "us-east-1",
           aws_access_key_id: "AKIAIOSFODNN7EXAMPLE",
           aws_secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
  end
  let(:logger) { double("Logger", error: nil, info: nil) }
  let(:sns_client) { double("SnsClient") }
  let(:transport) do
    described_class.new(
      configuration: configuration,
      logger: logger,
      sns_client: sns_client
    )
  end

  describe "#deliver" do
    let(:message) { { text: "Test message", subject: "Test Subject" } }
    let(:response) { double("Response", message_id: "msg-123") }

    context "when configuration is valid" do
      it "publishes message to SNS" do
        expect(sns_client).to receive(:publish).with(
          topic_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic",
          message: "{\n  \"text\": \"Test message\",\n  \"subject\": \"Test Subject\"\n}",
          subject: "Test Subject"
        ).and_return(response)

        expect(logger).to receive(:info).with("Newshound: Message sent to SNS, MessageId: msg-123")
        expect(transport.deliver(message)).to eq(true)
      end

      context "with Slack blocks format" do
        let(:message) do
          {
            blocks: [
              { type: "header", text: { text: "Daily Report" } },
              { type: "divider" },
              { type: "section", text: { text: "*Bold* and _italic_ text with :emoji:" } }
            ]
          }
        end

        it "formats Slack blocks for SNS" do
          expect(sns_client).to receive(:publish).with(
            topic_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic",
            message: "=== Daily Report ===\n\n---\n\nBold and italic text with ",
            subject: "Newshound Notification"
          ).and_return(response)

          expect(logger).to receive(:info).with("Newshound: Message sent to SNS, MessageId: msg-123")
          expect(transport.deliver(message)).to eq(true)
        end
      end

      context "when delivery fails" do
        it "logs error and returns false" do
          error = StandardError.new("AWS error")
          allow(sns_client).to receive(:publish).and_raise(error)
          expect(logger).to receive(:error).with("Newshound: Failed to send SNS notification: AWS error")
          expect(transport.deliver(message)).to eq(false)
        end
      end
    end

    context "when SNS topic ARN is missing" do
      before do
        allow(configuration).to receive(:sns_topic_arn).and_return(nil)
      end

      it "logs error and returns false" do
        expect(logger).to receive(:error).with("Newshound: SNS topic ARN not configured")
        expect(sns_client).not_to receive(:publish)
        expect(transport.deliver(message)).to eq(false)
      end
    end

    context "with string message" do
      let(:message) { "Simple text message" }

      it "sends string directly" do
        expect(sns_client).to receive(:publish).with(
          topic_arn: "arn:aws:sns:us-east-1:123456789012:MyTopic",
          message: "Simple text message",
          subject: "Newshound Notification"
        ).and_return(response)

        expect(logger).to receive(:info).with("Newshound: Message sent to SNS, MessageId: msg-123")
        expect(transport.deliver(message)).to eq(true)
      end
    end
  end
  end
rescue LoadError
  # Skip tests if aws-sdk-sns is not installed
end