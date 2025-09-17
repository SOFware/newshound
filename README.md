# Newshound 🐕

A Ruby gem that sniffs out exceptions and job statuses in your Rails app and reports them daily to Slack or other notification services.

## Features

- 📊 Daily Que job status reports (counts by job type, queue health)
- 🚨 Last 4 exceptions from exception-track
- 💬 Multiple transport options: Direct Slack or Amazon SNS
- ⏰ Automatic daily scheduling with que-scheduler
- 🔧 Configurable report times and limits
- 🔄 Environment-based transport switching (SNS for production, Slack for development)

## Installation

Add to your Gemfile:

```ruby
gem 'newshound', path: 'path/to/newshound'  # or from git/rubygems when published

# Optional: Add AWS SDK if using SNS transport
gem 'aws-sdk-sns', '~> 1.0'  # Only needed for SNS transport
```

Then:

```bash
bundle install
```

## Configuration

Create an initializer `config/initializers/newshound.rb`:

### Basic Configuration (Slack Direct)

```ruby
Newshound.configure do |config|
  # Transport selection (optional, defaults to :slack)
  config.transport_adapter = :slack

  # Slack configuration (choose one method)
  config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']  # Option 1: Webhook
  # OR set ENV['SLACK_API_TOKEN'] for Web API          # Option 2: Web API

  config.slack_channel = "#ops-alerts"     # Default: "#general"
  config.report_time = "09:00"            # Default: "09:00" (24-hour format)
  config.exception_limit = 4              # Default: 4 (last N exceptions)
  config.time_zone = "America/New_York"   # Default: "America/New_York"
  config.enabled = true                   # Default: true
end
```

### Production Configuration with SNS

```ruby
Newshound.configure do |config|
  if Rails.env.production?
    # Use SNS in production to route through AWS
    config.transport_adapter = :sns
    config.sns_topic_arn = ENV['SNS_TOPIC_ARN']
    config.aws_region = ENV['AWS_REGION'] || 'us-east-1'

    # Optional: Explicit AWS credentials (uses IAM role by default)
    config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
    config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  else
    # Use direct Slack in development/staging
    config.transport_adapter = :slack
    config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
  end

  # Common settings
  config.slack_channel = "#ops-alerts"
  config.report_time = "09:00"
  config.exception_limit = 4
  config.time_zone = "America/New_York"
  config.enabled = true
end
```

## Transport Setup

### Slack Setup (Direct Integration)

#### Option 1: Webhook URL (Simpler)
1. Go to https://api.slack.com/apps
2. Create a new app or select existing
3. Enable "Incoming Webhooks"
4. Add a new webhook for your channel
5. Copy the webhook URL to your config

#### Option 2: Web API Token (More features)
1. Create a Slack app at https://api.slack.com/apps
2. Add OAuth scopes: `chat:write`, `chat:write.public`
3. Install to workspace
4. Copy the Bot User OAuth Token
5. Set as `ENV['SLACK_API_TOKEN']`

### AWS SNS Setup (Production Routing)

1. **Create SNS Topic**:
   ```bash
   aws sns create-topic --name newshound-notifications
   ```

2. **Subscribe Slack Webhook to Topic**:
   ```bash
   aws sns subscribe \
     --topic-arn arn:aws:sns:us-east-1:123456789:newshound-notifications \
     --protocol https \
     --notification-endpoint YOUR_SLACK_WEBHOOK_URL
   ```

3. **Configure IAM Permissions**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": "sns:Publish",
       "Resource": "arn:aws:sns:us-east-1:*:newshound-*"
     }]
   }
   ```

4. **Set Environment Variables**:
   ```bash
   export SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789:newshound-notifications"
   export AWS_REGION="us-east-1"
   ```

## Usage

### Automatic Daily Reports

If you have `que-scheduler` configured, Newshound will automatically schedule daily reports at your configured time.

### Manual Reports

```ruby
# Send report immediately
Newshound.report!

# Or via rake task
rake newshound:report_now

# Enqueue for background processing
rake newshound:schedule

# Check configuration
rake newshound:config
```

### Integration with que-scheduler

Add to your `config/que_schedule.yml`:

```yaml
newshound_daily_report:
  class: "Newshound::DailyReportJob"
  cron: "0 9 * * *"  # 9:00 AM daily
  queue: default
```

Or let Newshound auto-configure based on your settings.

## Report Format

The daily report includes:

### Exception Section
- Last 4 exceptions (configurable)
- Exception class, message, controller/action
- Count of same exception type in last 24 hours
- Timestamp

### Que Jobs Section
- Job counts by type (success/failed/total)
- Queue health status
- Ready to run count
- Scheduled jobs count
- Failed jobs in retry queue
- Jobs completed today

## Development

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Console
bin/console
```

## Testing in Your App

```ruby
# In rails console

# Test Slack transport
Newshound.configuration.transport_adapter = :slack
Newshound.configuration.slack_webhook_url = "your-webhook"
Newshound.report!  # Should post to Slack immediately

# Test SNS transport
Newshound.configuration.transport_adapter = :sns
Newshound.configuration.sns_topic_arn = "your-topic-arn"
Newshound.report!  # Should publish to SNS
```

## Troubleshooting

- **No reports sent**: Check `rake newshound:config` to verify configuration
- **No exceptions showing**: Ensure `exception-track` gem is installed and logging
- **No job data**: Verify Que is configured and `que_jobs` table exists
- **Slack not receiving**: Verify webhook URL or API token is correct
- **SNS not publishing**: Check IAM permissions and topic ARN configuration
- **AWS SDK errors**: Ensure `aws-sdk-sns` gem is installed when using SNS transport

## License

MIT