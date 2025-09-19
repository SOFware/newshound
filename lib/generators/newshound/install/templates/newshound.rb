# frozen_string_literal: true

Newshound.configure do |config|
  # Slack webhook URL for sending reports (required)
  # You can get this from your Slack app settings
  config.slack_webhook_url = ENV.fetch("NEWSHOUND_SLACK_WEBHOOK_URL", nil)

  # Channel to post reports to
  # Default is "#general"
  config.slack_channel = "#engineering"

  # Time to send daily report (24-hour format)
  # Default is "09:00" (9:00 AM)
  config.report_time = "09:00"

  # Maximum number of exceptions to include in report
  # Default is 4
  config.exception_limit = 4

  # Time zone for scheduling reports
  # Default is "America/New_York"
  config.time_zone = "America/New_York"

  # Enable or disable Newshound completely
  # Useful for disabling in development/test environments
  # Default is true
  config.enabled = Rails.env.production?

  # Transport adapter (:slack or :sns)
  # Default is :slack
  config.transport_adapter = :slack

  # AWS SNS Configuration (only needed if transport_adapter is :sns)
  # config.sns_topic_arn = ENV.fetch("NEWSHOUND_SNS_TOPIC_ARN", nil)
  # config.aws_region = ENV.fetch("AWS_REGION", "us-east-1")
  # config.aws_access_key_id = ENV.fetch("AWS_ACCESS_KEY_ID", nil)
  # config.aws_secret_access_key = ENV.fetch("AWS_SECRET_ACCESS_KEY", nil)
end