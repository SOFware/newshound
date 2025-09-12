# Newshound 🐕

A Ruby gem that sniffs out exceptions and job statuses in your Rails app and reports them daily to Slack.

## Features

- 📊 Daily Que job status reports (counts by job type, queue health)
- 🚨 Last 4 exceptions from exception-track
- 💬 Slack integration via webhook or Web API
- ⏰ Automatic daily scheduling with que-scheduler
- 🔧 Configurable report times and limits

## Installation

Add to your Gemfile:

```ruby
gem 'newshound', path: 'path/to/newshound'  # or from git/rubygems when published
```

Then:

```bash
bundle install
```

## Configuration

Create an initializer `config/initializers/newshound.rb`:

```ruby
Newshound.configure do |config|
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

### Slack Setup

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
Newshound.configuration.slack_webhook_url = "your-webhook"
Newshound.report!  # Should post to Slack immediately
```

## Troubleshooting

- **No reports sent**: Check `rake newshound:config` to verify configuration
- **No exceptions showing**: Ensure `exception-track` gem is installed and logging
- **No job data**: Verify Que is configured and `que_jobs` table exists
- **Slack not receiving**: Verify webhook URL or API token is correct

## License

MIT