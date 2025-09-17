# frozen_string_literal: true

require_relative "base"

module Newshound
  module Transport
    class Sns < Base
      attr_reader :sns_client

      def initialize(configuration: nil, logger: nil, sns_client: nil)
        super(configuration: configuration, logger: logger)
        @sns_client = sns_client || build_sns_client
      end

      def deliver(message)
        return false unless valid_sns_configuration?

        formatted_message = format_message(message)

        response = sns_client.publish(
          topic_arn: configuration.sns_topic_arn,
          message: formatted_message,
          subject: extract_subject(message)
        )

        logger.info "Newshound: Message sent to SNS, MessageId: #{response.message_id}"
        true
      rescue StandardError => e
        logger.error "Newshound: Failed to send SNS notification: #{e.message}"
        false
      end

      private

      def build_sns_client
        require "aws-sdk-sns"

        options = {
          region: configuration.aws_region || ENV["AWS_REGION"] || "us-east-1"
        }

        if configuration.aws_access_key_id && configuration.aws_secret_access_key
          options[:credentials] = Aws::Credentials.new(
            configuration.aws_access_key_id,
            configuration.aws_secret_access_key
          )
        end

        Aws::SNS::Client.new(options)
      end

      def valid_sns_configuration?
        if configuration.sns_topic_arn.nil? || configuration.sns_topic_arn.empty?
          logger.error "Newshound: SNS topic ARN not configured"
          false
        else
          true
        end
      end

      def format_message(message)
        case message
        when Hash
          if message[:blocks]
            format_slack_blocks_for_sns(message[:blocks])
          else
            JSON.pretty_generate(message)
          end
        when String
          message
        else
          message.to_s
        end
      end

      def format_slack_blocks_for_sns(blocks)
        lines = []

        blocks.each do |block|
          case block[:type]
          when "section"
            if block[:text]
              lines << format_text_element(block[:text])
            end
          when "header"
            if block[:text]
              lines << "=== #{format_text_element(block[:text])} ==="
            end
          when "divider"
            lines << "---"
          end
        end

        lines.join("\n\n")
      end

      def format_text_element(text_element)
        return "" unless text_element

        text = text_element[:text] || ""
        text.gsub(/:([a-z_]+):/, '')
            .gsub(/\*(.+?)\*/, '\1')
            .gsub(/_(.+?)_/, '\1')
      end

      def extract_subject(message)
        if message.is_a?(Hash)
          message[:subject] || "Newshound Notification"
        else
          "Newshound Notification"
        end
      end
    end
  end
end