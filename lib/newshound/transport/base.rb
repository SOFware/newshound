# frozen_string_literal: true

module Newshound
  module Transport
    class Base
      attr_reader :configuration, :logger

      def initialize(configuration: nil, logger: nil)
        @configuration = configuration || Newshound.configuration
        @logger = logger || default_logger
      end

      def deliver(message)
        raise NotImplementedError, "Subclasses must implement the #deliver method"
      end

      protected

      def default_logger
        if defined?(Rails)
          Rails.logger
        else
          Logger.new(STDOUT)
        end
      end
    end
  end
end