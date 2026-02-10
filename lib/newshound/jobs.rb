# frozen_string_literal: true

Dir[File.join(__dir__, "jobs", "*.rb")].each { |file| require file }

module Newshound
  module Jobs
    @registry = {}

    class << self
      attr_reader :registry

      # Register a job adapter class with a symbolic name
      #
      # @param name [Symbol, String] The name to register the adapter under
      # @param adapter_class [Class] The adapter class (must inherit from Jobs::Base)
      def register(name, adapter_class)
        @registry[name.to_sym] = adapter_class
      end

      # Get a job source adapter instance
      #
      # @param source [Symbol, Object] Either a symbolic name to look up, or an adapter instance
      # @return [Jobs::Base] An instance of the job adapter
      # @raise [RuntimeError] If the source symbol cannot be resolved
      def source(source)
        return source unless source.is_a?(Symbol)

        if @registry.key?(source)
          return @registry[source].new
        end

        constant = constants.find { |c| c.to_s.gsub(/(?<!^)([A-Z])/, "_\\1").downcase == source.to_s }
        raise "Invalid job source: #{source}" unless constant

        const_get(constant).new
      end

      def clear_registry!
        @registry = {}
      end
    end
  end
end
