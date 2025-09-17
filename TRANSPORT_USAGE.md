# Transport Layer Usage

The Newshound gem now supports multiple transport adapters for sending notifications. You can choose between Slack (direct) and Amazon SNS based on your environment needs.

## Configuration

### Using Slack Transport (Default)

```ruby
# config/initializers/newshound.rb
Newshound.configure do |config|
  config.transport_adapter = :slack  # This is the default
  config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
  config.slack_channel = '#your-channel'
  # ... other configurations
end
```

### Using SNS Transport

```ruby
# config/initializers/newshound.rb
Newshound.configure do |config|
  config.transport_adapter = :sns
  config.sns_topic_arn = ENV['SNS_TOPIC_ARN']
  config.aws_region = ENV['AWS_REGION'] || 'us-east-1'

  # Optional: Provide AWS credentials explicitly
  # If not provided, will use default AWS credential chain
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']

  # ... other configurations
end
```

### Environment-based Configuration

You can switch transport based on environment:

```ruby
# config/initializers/newshound.rb
Newshound.configure do |config|
  if Rails.env.production?
    # Use SNS in production to route through AWS infrastructure
    config.transport_adapter = :sns
    config.sns_topic_arn = ENV['SNS_TOPIC_ARN']
    config.aws_region = ENV['AWS_REGION']
  else
    # Use direct Slack in development/staging
    config.transport_adapter = :slack
    config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
    config.slack_channel = '#dev-notifications'
  end

  # Common configurations
  config.report_time = "09:00"
  config.exception_limit = 4
  config.time_zone = "America/New_York"
end
```

## Custom Transport Adapters

You can also create your own transport adapter:

```ruby
class MyCustomTransport < Newshound::Transport::Base
  def deliver(message)
    # Your custom delivery logic here
    # Return true on success, false on failure

    # Example: Send to custom API endpoint
    response = HTTParty.post(
      'https://api.example.com/notifications',
      body: message.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    response.success?
  rescue StandardError => e
    logger.error "Failed to deliver: #{e.message}"
    false
  end
end

# Use the custom transport
Newshound.configure do |config|
  config.transport_adapter = MyCustomTransport
  # ... other configurations
end
```

## AWS SNS Setup

If using SNS transport, ensure you have:

1. Created an SNS topic in AWS
2. Subscribed your Slack webhook URL to the SNS topic
3. Configured proper IAM permissions for publishing to the topic
4. Installed the aws-sdk-sns gem (it's optional):

```ruby
# Add to your Gemfile if using SNS
gem 'aws-sdk-sns', '~> 1.0'
```

## Testing

The transport layer is fully testable. You can inject mock transports in your tests:

```ruby
# In your tests
mock_transport = double('Transport', deliver: true)
notifier = Newshound::SlackNotifier.new(transport: mock_transport)
notifier.post({ text: "Test message" })
```