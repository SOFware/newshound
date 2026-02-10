# frozen_string_literal: true

module Newshound
  class Configuration
    attr_accessor :exception_limit, :enabled, :authorized_roles,
      :current_user_method, :authorization_block, :exception_source,
      :warning_source, :warning_limit, :job_source

    def initialize
      @exception_limit = 10
      @enabled = true
      @authorized_roles = [:developer, :super_user]
      @current_user_method = :current_user
      @authorization_block = nil
      @exception_source = :exception_track
      @warning_source = nil
      @warning_limit = 10
      @job_source = nil
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
