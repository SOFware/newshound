# frozen_string_literal: true

module Newshound
  class Configuration
    POSITIONS = %i[top bottom].freeze

    attr_accessor :exception_limit, :enabled, :authorized_roles,
      :current_user_method, :authorization_block, :exception_source,
      :exception_source_config,
      :warning_source, :warning_limit, :job_source,
      :expired_jobs_threshold,
      :exception_links, :job_links, :warning_links

    # The pre-1.0.4 name. It now gates expired jobs rather than every errored job,
    # so a value tuned to absorb retries is worth revisiting.
    alias_method :failed_jobs_threshold, :expired_jobs_threshold
    alias_method :failed_jobs_threshold=, :expired_jobs_threshold=

    attr_reader :position

    def initialize
      @exception_limit = 10
      @enabled = true
      @authorized_roles = [:developer, :super_user]
      @current_user_method = :current_user
      @authorization_block = nil
      @exception_source = :exception_track
      @exception_source_config = {}
      @warning_source = nil
      @warning_limit = 10
      @job_source = nil
      @expired_jobs_threshold = 0
      @exception_links = {}
      @job_links = {}
      @warning_links = {}
      @position = :top
    end

    # Which viewport edge the banner attaches to, :top or :bottom
    def position=(value)
      unless POSITIONS.include?(value)
        raise ArgumentError,
          "Invalid position: #{value.inspect}. Must be :top or :bottom"
      end

      @position = value
    end

    # Allow custom authorization logic
    def authorize_with(&block)
      @authorization_block = block
    end

    def valid?
      enabled
    end
  end
end
