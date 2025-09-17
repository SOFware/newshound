# frozen_string_literal: true

require "slack-ruby-client"

module Newshound
  class SlackNotifier
    attr_reader :configuration, :logger, :transport

    def initialize(configuration: nil, logger: nil, transport: nil)
      @configuration = configuration || Newshound.configuration
      @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new(STDOUT))
      @transport = transport || build_transport
    end

    def post(message)
      return unless configuration.valid?

      transport.deliver(message)
    rescue StandardError => e
      logger.error "Newshound: Failed to send notification: #{e.message}"
    end

    private

    def build_transport
      case configuration.transport_adapter
      when :sns, "sns"
        require_relative "transport/sns"
        Transport::Sns.new(configuration: configuration, logger: logger)
      when :slack, "slack", nil
        require_relative "transport/slack"
        Transport::Slack.new(configuration: configuration, logger: logger)
      else
        if configuration.transport_adapter.is_a?(Class)
          configuration.transport_adapter.new(configuration: configuration, logger: logger)
        elsif configuration.transport_adapter.respond_to?(:new)
          configuration.transport_adapter.new(configuration: configuration, logger: logger)
        else
          raise ArgumentError, "Invalid transport adapter: #{configuration.transport_adapter}"
        end
      end
    end
  end
end