# Newshound 🐕

A Ruby gem that displays real-time exceptions and job statuses in a collapsible banner for authorized users in your Rails application.

## Features

- 🎯 **Real-time Web UI Banner** - Shows exceptions and job statuses at the top of every page
- 🔐 **Role-Based Access** - Only visible to authorized users (developers, admins, etc.)
- 📊 **Que Job Monitoring** - Real-time queue health and job status
- 🚨 **Exception Tracking** - Recent exceptions from exception-track
- 🎨 **Collapsible UI** - Clean, non-intrusive banner that expands on click
- ⚡ **Zero Configuration** - Automatically injects into HTML responses
- 🔧 **Highly Customizable** - Configure roles and authorization logic

## Installation

Add to your Gemfile:

```ruby
gem 'newshound'
```

Then:

```bash
bundle install
rails generate newshound:install
```

The generator will create `config/initializers/newshound.rb` with default configuration.

## Configuration

### Basic Configuration

```ruby
# config/initializers/newshound.rb
Newshound.configure do |config|
  # Enable or disable the banner
  config.enabled = true

  # Maximum number of exceptions to show in banner
  config.exception_limit = 10

  # User roles that can view the banner
  config.authorized_roles = [:developer, :super_user]

  # Method to call to get current user (most apps use :current_user)
  config.current_user_method = :current_user
end
```

### Advanced: Custom Authorization

If the default role-based authorization doesn't fit your needs, you can provide custom logic:

```ruby
# config/initializers/newshound.rb
Newshound.authorize_with do |controller|
  # Your custom authorization logic
  # Return true to show banner, false to hide
  user = controller.current_user
  user&.admin? || user&.developer?
end
```

### Example Authorization Scenarios

```ruby
# Only show in development
Newshound.authorize_with do |controller|
  Rails.env.development?
end

# Check multiple conditions
Newshound.authorize_with do |controller|
  user = controller.current_user
  user.present? &&
    (user.has_role?(:admin) || user.email.ends_with?('@yourcompany.com'))
end

# Use your existing authorization system
Newshound.authorize_with do |controller|
  controller.current_user&.can?(:view_newshound)
end
```

## How It Works

Newshound uses Rails middleware to automatically inject a banner into HTML responses for authorized users. The banner:

1. ✅ Appears automatically on all HTML pages
2. 🔒 Only visible to users with authorized roles
3. 📊 Shows real-time data from your exception and job queues
4. 🎨 Collapses to save space, expands on click
5. 🚀 No JavaScript dependencies, pure CSS animations

## Banner Content

The banner displays:

### Exception Section
- Recent exceptions from exception-track
- Exception class and message
- Controller/action where it occurred
- Timestamp
- Visual indicators (🟢 all clear / 🔴 errors)

### Job Queue Section
- **Ready to Run**: Jobs waiting to execute
- **Scheduled**: Jobs scheduled for future execution
- **Failed**: Jobs in retry queue
- **Completed Today**: Successfully finished jobs
- Color-coded health status

## User Requirements

Your User model should have a `role` attribute that matches one of the configured `authorized_roles`. Common patterns:

```ruby
# String enum
class User < ApplicationRecord
  enum role: { user: 'user', developer: 'developer', admin: 'admin' }
end

# Symbol enum
class User < ApplicationRecord
  enum role: { user: 0, developer: 1, super_user: 2 }
end

# String column
class User < ApplicationRecord
  def role
    @role ||= read_attribute(:role)&.to_sym
  end
end
```

If your User model uses different attribute names, you can customize the authorization logic using `Newshound.authorize_with`.

## Testing

### Test Reporters

```bash
# Test exception reporter
rake newshound:test_exceptions

# Test job queue reporter
rake newshound:test_jobs

# Show current configuration
rake newshound:config
```

### Test in Rails Console

```ruby
# Check if banner would show for a specific user
user = User.find(123)
controller = ApplicationController.new
controller.instance_variable_set(:@current_user, user)
Newshound::Authorization.authorized?(controller)
# => true or false
```

## Troubleshooting

### Banner not appearing

1. **Check if enabled**: `rake newshound:config`
2. **Verify user role**: Make sure your user has an authorized role
3. **Check current_user method**: Ensure your app provides the configured method
4. **Restart server**: Changes to initializers require a restart

### No exceptions showing

- Ensure `exception-track` gem is installed and logging exceptions
- Check that exceptions exist: `rake newshound:test_exceptions`

### No job data

- Verify Que is configured and `que_jobs` table exists
- Check job data: `rake newshound:test_jobs`

### Banner appears for wrong users

- Review `authorized_roles` configuration
- Consider using custom authorization with `Newshound.authorize_with`

## Development

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Console
bin/console
```

## Release Management

This gem uses [Reissue](https://github.com/rails/reissue) for release management. To release a new version, perform
the following steps as you would with any other ruby gem:

```bash
bundle exec rake bump:checksum
```
And then create a new release:
```bash
bundle exec rake release
```

The final step is to push your version bump branch, open a PR, and merge it.

## Dependencies

- **Rails** >= 6.0
- **que** >= 1.0 (for job monitoring)
- **exception-track** >= 0.1 (for exception tracking)

## Upgrading from 0.1.x

If you were using the previous Slack-based version:

1. Remove Slack/SNS configuration from your initializer
2. Remove `que-scheduler` if only used for Newshound
3. Update to new configuration format (see above)
4. Restart your Rails server

The banner will now appear automatically for authorized users instead of sending Slack notifications.

## License

MIT