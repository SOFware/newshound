# frozen_string_literal: true

Dir[File.join(__dir__, "warnings", "*.rb")].each { |file| require file }

module Newshound
  module Warnings
    # Registry for warning adapters
    # Allows applications to register custom warning sources without
    # needing to create classes within the Newshound namespace
    @registry = {}

    class << self
      # Access the registry of registered adapters
      # @return [Hash] The registry hash mapping names to adapter classes
      attr_reader :registry

      # Register a warning adapter class with a symbolic name
      #
      # @param name [Symbol, String] The name to register the adapter under
      # @param adapter_class [Class] The adapter class (must inherit from Warnings::Base)
      # @example
      #   Newshound::Warnings.register(:unprocessable_events, MyApp::UnprocessableEventsWarning)
      def register(name, adapter_class)
        @registry[name.to_sym] = adapter_class
      end

      # Get a warning source adapter instance
      #
      # @param source [Symbol, Object] Either a symbolic name to look up, or an adapter instance
      # @return [Warnings::Base] An instance of the warning adapter
      # @raise [RuntimeError] If the source symbol cannot be resolved
      # @example
      #   Newshound::Warnings.source(:unprocessable_events)
      #   Newshound::Warnings.source(MyAdapter.new)
      def source(source)
        return source unless source.is_a?(Symbol)

        # First check the registry
        if @registry.key?(source)
          return @registry[source].new
        end

        # Fall back to constant lookup (like Exceptions module)
        constant = constants.find { |c| c.to_s.gsub(/(?<!^)([A-Z])/, "_\\1").downcase == source.to_s }
        raise "Invalid warning source: #{source}" unless constant

        const_get(constant).new
      end

      # Clear the registry (primarily for testing)
      def clear_registry!
        @registry = {}
      end
    end
  end
end
