# frozen_string_literal: true

Newshound.configure do |config|
  # Enable or disable Newshound completely
  # When enabled, the banner will be shown to authorized users
  # Default is true
  config.enabled = true

  # Maximum number of exceptions to include in banner
  # Default is 10
  config.exception_limit = 10

  # Exception source to use for exceptions
  # Default is :exception_track
  config.exception_source = :exception_track # or :solid_errors

  # Job source adapter for monitoring background jobs
  # Uncomment and set to enable job monitoring in the banner
  # config.job_source = :que # or a custom adapter instance
  # See Newshound::Jobs::Base for the adapter interface

  # User roles that are authorized to view the Newshound banner
  # These should match the role values in your User model
  # Default is [:developer, :super_user]
  config.authorized_roles = [:developer, :super_user]

  # Method name to call to get the current user
  # Most apps use :current_user (Devise, etc.)
  # Default is :current_user
  config.current_user_method = :current_user

  # Links for banner items
  # Configure paths so banner items link to your exception/job dashboards.
  # Use :id in show paths to interpolate the record ID.
  #
  # config.exception_links = {
  #   index: "/errors",
  #   show: "/errors/:id"
  # }
  #
  # config.job_links = {
  #   index: "/background_jobs",
  #   show: "/background_jobs/jobs/:id",
  #   scheduled: "/background_jobs/scheduled",
  #   failed: "/background_jobs/failed",
  #   completed: "/background_jobs/completed"
  # }
  #
  # config.warning_links = {
  #   index: "/warnings",
  #   show: "/warnings/:id"
  # }

  # Custom authorization logic:
  # If the default role-based authorization doesn't fit your needs,
  # you can provide a custom authorization block:
  #
  # config.authorize_with do |controller|
  #   # Your custom logic here
  #   # Return true to show the banner, false to hide it
  #   controller.current_user&.admin?
  # end
end
