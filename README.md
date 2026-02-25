# TelegramBotEngine

A mountable Rails engine that adds subscriber management, authorization, broadcasting, and an admin UI on top of the [`telegram-bot`](https://github.com/telegram-bot-rb/telegram-bot) gem (v0.16.x).

The `telegram-bot` gem handles all Telegram protocol concerns (API client, webhook ingestion, controller/command routing, callback queries, session, async delivery, and testing). This engine adds the persistence and management layer that `telegram-bot` deliberately doesn't provide.

## Installation

Add to your Gemfile:

```ruby
gem "telegram_bot_engine"
```

Install migrations:

```bash
bin/rails telegram_bot_engine:install:migrations
bin/rails db:migrate
```

## Configuration

### Bot token

Following `telegram-bot`'s convention, configure via Rails credentials:

```yaml
# config/credentials.yml.enc
telegram:
  bot:
    token: "YOUR_BOT_TOKEN"
    username: "your_bot"
```

### Engine configuration

```ruby
# config/initializers/telegram_bot_engine.rb
TelegramBotEngine.configure do |config|
  # Authorization: only these Telegram usernames can /start and subscribe.
  config.allowed_usernames = %w[alice bob charlie]
  # OR dynamic:
  # config.allowed_usernames = -> { MyModel.pluck(:telegram_username) }
  # OR managed via admin UI:
  # config.allowed_usernames = :database
  # OR open access (no allowlist):
  # config.allowed_usernames = nil

  # Optional: disable admin UI
  # config.admin_enabled = false

  # Optional: custom messages
  # config.unauthorized_message = "Sorry, you're not authorized to use this bot."
  # config.welcome_message = "Welcome %{username}! Available commands:\n%{commands}"
end
```

### Webhook controller

Create a controller inheriting from `telegram-bot`'s `UpdatesController` and include the engine's concern:

```ruby
# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include TelegramBotEngine::SubscriberCommands
  # Provides: start!, stop!, help! with authorization and subscription management.

  # Add your own commands:
  def status!(*)
    respond_with :message, text: "All systems operational"
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  telegram_webhook TelegramWebhookController

  # Mount admin UI (protect with your own authentication)
  authenticate :user, ->(u) { u.admin? } do
    mount TelegramBotEngine::Engine, at: "/telegram/admin"
  end
end
```

### Set webhook

These rake tasks come from the `telegram-bot` gem:

```bash
# Register your app's URL with Telegram so it sends updates to your server
bin/rails telegram:bot:set_webhook RAILS_ENV=production

# Remove the webhook (e.g. before switching to polling)
bin/rails telegram:bot:delete_webhook

# Run a local poller for development (no webhook needed)
bin/rails telegram:bot:poller
```

The webhook URL is derived from your Rails routes (`telegram_webhook` route helper). Make sure your production server is accessible via HTTPS before setting the webhook.

For local development with ngrok, configure `default_url_options` in `config/environments/development.rb`:

```ruby
if ENV['HOST'].present?
  routes.default_url_options[:host] = ENV.fetch("HOST", "localhost:3000")
  routes.default_url_options[:protocol] = ENV.fetch("PROTOCOL", "https")
end
```

Then run:

```bash
HOST=your-subdomain.ngrok-free.app bin/rails telegram:bot:set_webhook
```

## Usage

### Broadcasting

```ruby
# Broadcast to all active subscribers
TelegramBotEngine.broadcast("Deployment complete!")

# With Markdown formatting
TelegramBotEngine.broadcast(
  "*Deploy complete*\nVersion: `v2.3.4`",
  parse_mode: "Markdown"
)
```

### Direct messaging

```ruby
TelegramBotEngine.notify(
  chat_id: 123456789,
  text: "Your report is ready."
)
```

### Admin UI

When mounted, the engine provides a web interface for:
- **Dashboard** — bot info, subscription counts
- **Subscriptions** — list, activate/deactivate, delete
- **Allowlist** — add/remove usernames (when `config.allowed_usernames = :database`)

## Requirements

- Ruby >= 3.3.0
- Rails >= 7.0
- `telegram-bot` ~> 0.16

## License

MIT
