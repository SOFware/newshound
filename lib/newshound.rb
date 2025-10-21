# frozen_string_literal: true

require_relative "newshound/version"
require_relative "newshound/configuration"
require_relative "newshound/exception_reporter"
require_relative "newshound/que_reporter"
require_relative "newshound/authorization"
require_relative "newshound/middleware/banner_injector"
require_relative "newshound/railtie" if defined?(Rails)

module Newshound
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Allow setting custom authorization logic
    def authorize_with(&block)
      configuration.authorize_with(&block)
    end
  end
end
