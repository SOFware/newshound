# frozen_string_literal: true

Newshound.configure do |config|
  # Enable or disable Newshound completely
  # When enabled, the banner will be shown to authorized users
  # Default is true
  config.enabled = true

  # Maximum number of exceptions to include in banner
  # Default is 10
  config.exception_limit = 10

  # User roles that are authorized to view the Newshound banner
  # These should match the role values in your User model
  # Default is [:developer, :super_user]
  config.authorized_roles = [:developer, :super_user]

  # Method name to call to get the current user
  # Most apps use :current_user (Devise, etc.)
  # Default is :current_user
  config.current_user_method = :current_user
end

# Advanced: Custom authorization logic
# If the default role-based authorization doesn't fit your needs,
# you can provide a custom authorization block:
#
# Newshound.authorize_with do |controller|
#   # Your custom logic here
#   # Return true to show the banner, false to hide it
#   controller.current_user&.admin?
# end
