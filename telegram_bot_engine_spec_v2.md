# TelegramBotEngine — Rails Engine Specification

## Overview

`telegram_bot_engine` is a mountable Rails engine (distributed as a gem) that adds subscriber management, authorization, broadcasting, and admin UI on top of the [`telegram-bot`](https://github.com/telegram-bot-rb/telegram-bot) gem (v0.16.x). The `telegram-bot` gem handles all Telegram protocol concerns — API client, webhook ingestion, controller/command routing, callback queries, session, async delivery, and testing. Our engine adds the persistence and management layer that `telegram-bot` deliberately doesn't provide.

The engine follows a **one bot per host app** model. Each Rails app that mounts the engine configures its own bot token and defines its own command handlers using `telegram-bot`'s native controller pattern.

## Design Principles

- **Build on `telegram-bot`, don't reinvent it**: commands, webhooks, client, session, testing — all come from the gem
- **Engine owns subscriber persistence and authorization**: the missing layer
- **Host app owns domain logic**: command handlers live in the host app's controller
- **ActiveJob for broadcast delivery**: works with whatever queue backend the host uses
- **Authentication delegated to host app**: admin routes are protected by the host app via routing constraints

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Host Rails App                                           │
│                                                           │
│  ┌──────────────────────────────────┐                    │
│  │  TelegramWebhookController       │ ◄── host app owns │
│  │  (inherits telegram-bot's        │     this controller│
│  │   UpdatesController)             │                    │
│  │                                  │                    │
│  │  def start!(...) ◄── engine provides this via concern │
│  │  def stop!(...)  ◄── engine provides this via concern │
│  │  def help!(...)  ◄── engine provides this via concern │
│  │  def park!(...)  ◄── host app defines these           │
│  │  def mute!(...)  ◄── host app defines these           │
│  └───────────┬──────────────────────┘                    │
│              │                                            │
│  ┌───────────▼──────────────────────────────────────────┐│
│  │  TelegramBotEngine (mounted at /telegram)             ││
│  │                                                       ││
│  │  Models:          Services:         Admin UI:         ││
│  │  - Subscription   - Broadcaster     - Subscriptions   ││
│  │  - AllowedUser    - Authorizer      - Allowlist       ││
│  │                   - DeliveryJob     - Dashboard       ││
│  │                                                       ││
│  │  Concern:                                             ││
│  │  - SubscriberCommands (start!/stop!/help!)            ││
│  └───────────┬───────────────────────────────────────────┘│
│              │                                            │
│  ┌───────────▼──────────────────────────────────────────┐│
│  │  telegram-bot gem (v0.16.x)                           ││
│  │                                                       ││
│  │  - Telegram::Bot::Client (API calls)                  ││
│  │  - Telegram::Bot::UpdatesController (command routing) ││
│  │  - Webhook middleware & route helpers                  ││
│  │  - Async mode (ActiveJob delivery)                    ││
│  │  - Session support                                    ││
│  │  - CallbackQueryContext                               ││
│  │  - RSpec helpers & matchers                           ││
│  └───────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
         │                              ▲
         ▼                              │
   Telegram Bot API              Telegram Bot API
   (receive webhooks)            (send messages)
```

---

## Dependencies

- `rails` >= 7.0
- `telegram-bot` ~> 0.16 (provides client, controllers, webhooks, async, testing)

No other runtime dependencies.

---

## Installation & Setup

### 1. Gemfile

```ruby
gem "telegram_bot_engine"
# telegram-bot is pulled in as a dependency automatically
```

### 2. Install migrations

```bash
bin/rails telegram_bot_engine:install:migrations
bin/rails db:migrate
```

### 3. Configure the bot token

Following `telegram-bot`'s convention, the bot token is configured via Rails credentials or secrets:

```yaml
# config/credentials.yml.enc (or config/secrets.yml)
telegram:
  bot:
    token: "YOUR_BOT_TOKEN"
    username: "parking_detect_bot"
```

### 4. Configure the engine

```ruby
# config/initializers/telegram_bot_engine.rb
TelegramBotEngine.configure do |config|
  # Authorization: only these Telegram usernames can /start and subscribe.
  # Accepts an array, a proc/lambda, or :database (managed via admin UI).
  config.allowed_usernames = %w[landovsky colleague1 colleague2]
  # OR
  config.allowed_usernames = -> { TelegramBotEngine::AllowedUser.pluck(:username) }
  # OR
  config.allowed_usernames = :database  # managed entirely via admin UI

  # Optional: disable admin UI (e.g., for API-only apps)
  config.admin_enabled = true  # default

  # Optional: custom unauthorized message
  config.unauthorized_message = "Sorry, you're not authorized to use this bot."

  # Optional: custom welcome message (supports %{username} and %{commands} interpolation)
  config.welcome_message = "Welcome %{username}! Available commands:\n%{commands}"
end
```

### 5. Create the webhook controller

The host app creates its own controller inheriting from `telegram-bot`'s `UpdatesController` and includes the engine's concern for subscriber management:

```ruby
# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include TelegramBotEngine::SubscriberCommands
  # This concern provides: start!, stop!, help!
  # with authorization, subscription management, and command listing.

  # --- Host app commands below ---

  def park!(*args)
    zone = args.first || "default"
    ParkingDetector.toggle_mode!(zone: zone)
    respond_with :message, text: "✅ Parking mode toggled for #{zone} zone"
  end

  def status!(*)
    s = ParkingDetector.current_status
    respond_with :message, text: [
      "📊 *Parking Detector Status*",
      "",
      "Mode: `#{s.mode}`",
      "Spaces monitored: #{s.space_count}",
      "Currently occupied: #{s.occupied_count}",
      "Last event: #{s.last_event_at&.strftime('%H:%M') || 'none'}"
    ].join("\n")
  end

  def mute!(*args)
    minutes = (args.first || 30).to_i
    sub = TelegramBotEngine::Subscription.find_by(chat_id: chat["id"])
    sub&.update(metadata: sub.metadata.merge("muted_until" => minutes.minutes.from_now.iso8601))
    respond_with :message, text: "🔇 Muted for #{minutes} minutes"
  end
end
```

### 6. Set up routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # telegram-bot's webhook route helper (connects bot to controller)
  telegram_webhook TelegramWebhookController

  # Engine admin UI (protected by host app)
  authenticate :user, ->(u) { u.admin? } do
    mount TelegramBotEngine::Engine, at: "/telegram/admin"
  end
  # OR with HTTP basic auth
  mount TelegramBotEngine::Engine, at: "/telegram/admin",
    constraints: ->(req) {
      ActionController::HttpAuthentication::Basic.has_basic_credentials?(req) &&
      ActionController::HttpAuthentication::Basic.decode_credentials(req) == ["admin", ENV["ADMIN_PASSWORD"]]
    }
end
```

Note: the webhook route and admin routes are separate. `telegram_webhook` is provided by the `telegram-bot` gem and handles the Telegram webhook endpoint. The engine mount is only for the admin UI.

### 7. Set Telegram webhook

```bash
# Using telegram-bot's built-in rake task
bin/rails telegram:bot:set_webhook
```

---

## Database Schema

### telegram_bot_engine_subscriptions

| Column     | Type     | Notes                              |
|------------|----------|------------------------------------|
| id         | bigint   | PK                                 |
| chat_id    | bigint   | Telegram chat ID, unique, not null |
| user_id    | bigint   | Telegram user ID                   |
| username   | string   | Telegram username                  |
| first_name | string   | Telegram first name                |
| active     | boolean  | Default: true                      |
| metadata   | jsonb    | Flexible storage for host app use  |
| created_at | datetime |                                    |
| updated_at | datetime |                                    |

Indexes: unique on `chat_id`, index on `active`, index on `username`.

The `metadata` jsonb column allows the host app to store arbitrary data per subscription without extending the schema (e.g., `muted_until`, notification preferences, linked host app user ID, future topic subscriptions).

### telegram_bot_engine_allowed_users

| Column     | Type     | Notes                               |
|------------|----------|-------------------------------------|
| id         | bigint   | PK                                  |
| username   | string   | Telegram username, unique, not null |
| note       | string   | Optional label (e.g., "Tom - dev")  |
| created_at | datetime |                                     |
| updated_at | datetime |                                     |

Used when `config.allowed_usernames = :database`. Ignored when allowlist is configured via array or proc.

---

## Engine-Provided Concern: SubscriberCommands

The engine provides a controller concern that the host app includes in its `TelegramWebhookController`. This concern implements the three built-in commands and the authorization gate.

```ruby
# lib/telegram_bot_engine/subscriber_commands.rb
module TelegramBotEngine
  module SubscriberCommands
    extend ActiveSupport::Concern

    included do
      # Authorization check runs before every command
      before_action :authorize_user!
    end

    # /start — create subscription if authorized
    def start!(*)
      subscription = TelegramBotEngine::Subscription.find_or_initialize_by(
        chat_id: chat["id"]
      )
      subscription.assign_attributes(
        user_id: from["id"],
        username: from["username"],
        first_name: from["first_name"],
        active: true
      )
      subscription.save!

      welcome = TelegramBotEngine.config.welcome_message % {
        username: from["first_name"] || from["username"],
        commands: available_commands_text
      }
      respond_with :message, text: welcome
    end

    # /stop — deactivate subscription
    def stop!(*)
      subscription = TelegramBotEngine::Subscription.find_by(chat_id: chat["id"])
      subscription&.update(active: false)
      respond_with :message, text: "👋 You've been unsubscribed. Send /start to resubscribe."
    end

    # /help — list all available commands
    def help!(*)
      respond_with :message, text: "📋 *Available Commands*\n\n#{available_commands_text}",
                   parse_mode: "Markdown"
    end

    private

    def authorize_user!
      return if TelegramBotEngine::Authorizer.authorized?(from["username"])

      respond_with :message, text: TelegramBotEngine.config.unauthorized_message
      throw :abort  # halt action chain
    end

    # Auto-generates command list from public methods ending with !
    def available_commands_text
      commands = self.class.public_instance_methods(false)
                     .select { |m| m.to_s.end_with?("!") }
                     .map { |m| "/#{m.to_s.delete_suffix('!')}" }

      all_commands = ["/start", "/stop", "/help"] | commands
      all_commands.join("\n")
    end
  end
end
```

### How authorization works

The `Authorizer` checks the Telegram username against the configured allowlist:

```ruby
# lib/telegram_bot_engine/authorizer.rb
module TelegramBotEngine
  class Authorizer
    def self.authorized?(username)
      return true if TelegramBotEngine.config.allowed_usernames.nil?

      allowed = resolve_allowed_usernames
      allowed.map(&:downcase).include?(username&.downcase)
    end

    private

    def self.resolve_allowed_usernames
      config = TelegramBotEngine.config.allowed_usernames

      case config
      when Array
        config
      when Proc
        config.call
      when :database
        TelegramBotEngine::AllowedUser.pluck(:username)
      else
        []
      end
    end
  end
end
```

---

## Outbound Messaging API

### Broadcasting to all active subscribers

```ruby
# Simple broadcast to all active subscribers
TelegramBotEngine.broadcast("🚨 Production deployment starting...")

# With parse_mode
TelegramBotEngine.broadcast(
  "✅ *Deploy complete*\nVersion: `v2.3.4`",
  parse_mode: "Markdown"
)

# With inline keyboard
TelegramBotEngine.broadcast(
  "🚗 Space occupied. Acknowledge?",
  reply_markup: {
    inline_keyboard: [[
      { text: "✅ Acknowledge", callback_data: "ack_parking" }
    ]]
  }
)
```

### Sending to a specific chat

```ruby
TelegramBotEngine.notify(
  chat_id: 123456789,
  text: "🚗 Parking space occupied at #{Time.current.strftime('%H:%M')}"
)

# With options
TelegramBotEngine.notify(
  chat_id: 123456789,
  text: "*Alert*: space freed",
  parse_mode: "Markdown"
)
```

### Implementation

```ruby
# lib/telegram_bot_engine.rb
module TelegramBotEngine
  # Broadcast to all active subscribers via background jobs
  def self.broadcast(text, **options)
    TelegramBotEngine::Subscription.active.find_each do |subscription|
      TelegramBotEngine::DeliveryJob.perform_later(
        subscription.chat_id,
        text,
        options
      )
    end
  end

  # Send to a specific chat via background job
  def self.notify(chat_id:, text:, **options)
    TelegramBotEngine::DeliveryJob.perform_later(chat_id, text, options)
  end
end
```

### DeliveryJob

```ruby
# app/jobs/telegram_bot_engine/delivery_job.rb
module TelegramBotEngine
  class DeliveryJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(chat_id, text, options = {})
      Telegram.bot.send_message(
        chat_id: chat_id,
        text: text,
        **options.symbolize_keys
      )
    rescue Telegram::Bot::Forbidden
      # User blocked the bot — deactivate subscription
      TelegramBotEngine::Subscription.where(chat_id: chat_id).update_all(active: false)
      Rails.logger.info("[TelegramBotEngine] Deactivated subscription for blocked chat: #{chat_id}")
    end
  end
end
```

The job uses `Telegram.bot` (the default bot client from the `telegram-bot` gem) to send messages. It catches `Telegram::Bot::Forbidden` (raised when a user has blocked the bot) and automatically deactivates their subscription.

---

## Callback Queries

For handling inline keyboard button presses, use `telegram-bot`'s native `CallbackQueryContext`:

```ruby
# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include TelegramBotEngine::SubscriberCommands
  include Telegram::Bot::UpdatesController::CallbackQueryContext

  # Handles callback_data starting with "ack_parking:"
  def ack_parking_callback_query(value = nil, *)
    ParkingEvent.find(value)&.acknowledge! if value
    answer_callback_query "Acknowledged!"
  end

  # Handles callback_data starting with "snooze:"
  def snooze_callback_query(minutes = "30", *)
    # ...
    answer_callback_query "Snoozed for #{minutes} minutes"
  end
end
```

This is entirely provided by the `telegram-bot` gem. No engine code needed.

---

## Admin UI

The engine mounts a minimal admin interface for managing subscriptions and the allowlist. It is server-rendered ERB with minimal inline CSS — no asset pipeline dependency.

### Routes (under the engine mount point)

| Route                          | Description                                |
|--------------------------------|--------------------------------------------|
| `GET  /`                       | Dashboard (subscription count, bot info)   |
| `GET  /subscriptions`          | List all subscriptions                     |
| `PATCH /subscriptions/:id`     | Toggle active/inactive                     |
| `DELETE /subscriptions/:id`    | Delete a subscription                      |
| `GET  /allowlist`              | List allowed usernames                     |
| `POST /allowlist`              | Add username to allowlist                  |
| `DELETE /allowlist/:id`        | Remove from allowlist                      |

### Dashboard shows

- Bot username and `t.me/` link for easy sharing/onboarding
- Total subscriptions (active / inactive)
- Quick link to subscriptions and allowlist management

### Subscriptions list shows

- Username, first name, chat_id, active status, created_at
- Toggle active/inactive button
- Delete button (with confirmation)

### Allowlist management (only shown when `config.allowed_usernames = :database`)

- Current allowed usernames with notes
- Add new username form
- Delete button per entry

### Disabling admin

```ruby
TelegramBotEngine.configure do |config|
  config.admin_enabled = false
end
```

When disabled, the engine still provides models, concern, broadcasting, and delivery — just no web UI.

---

## Gem File Structure

```
telegram_bot_engine/
├── app/
│   ├── controllers/
│   │   └── telegram_bot_engine/
│   │       └── admin/
│   │           ├── base_controller.rb          # Layout, engine root
│   │           ├── dashboard_controller.rb
│   │           ├── subscriptions_controller.rb
│   │           └── allowlist_controller.rb
│   ├── jobs/
│   │   └── telegram_bot_engine/
│   │       └── delivery_job.rb                 # Single message delivery
│   ├── models/
│   │   └── telegram_bot_engine/
│   │       ├── subscription.rb
│   │       └── allowed_user.rb
│   └── views/
│       └── telegram_bot_engine/
│           └── admin/
│               ├── layouts/
│               │   └── application.html.erb
│               ├── dashboard/
│               │   └── show.html.erb
│               ├── subscriptions/
│               │   └── index.html.erb
│               └── allowlist/
│                   └── index.html.erb
├── config/
│   └── routes.rb                               # Admin UI routes only
├── db/
│   └── migrate/
│       ├── 001_create_telegram_bot_engine_subscriptions.rb
│       └── 002_create_telegram_bot_engine_allowed_users.rb
├── lib/
│   ├── telegram_bot_engine.rb                  # Main module: configure, broadcast, notify
│   ├── telegram_bot_engine/
│   │   ├── engine.rb                           # Rails::Engine subclass
│   │   ├── configuration.rb                    # Config DSL
│   │   ├── authorizer.rb                       # Allowlist checking
│   │   └── subscriber_commands.rb              # Controller concern (start!/stop!/help!)
│   └── tasks/
│       └── telegram_bot_engine.rake            # Engine-specific rake tasks (if any)
├── telegram_bot_engine.gemspec
├── Gemfile
└── README.md
```

---

## Example: DevOps Notification App (API-only)

Minimal Rails API app that receives GitHub Actions webhooks and broadcasts CI/CD status.

```ruby
# Gemfile
gem "rails", "~> 8.0"
gem "telegram_bot_engine"

# config/credentials.yml.enc
telegram:
  bot:
    token: "BOT_TOKEN_HERE"
    username: "my_devops_bot"

# config/initializers/telegram_bot_engine.rb
TelegramBotEngine.configure do |config|
  config.allowed_usernames = %w[landovsky colleague1 colleague2]
  config.admin_enabled = false
end

# config/routes.rb
Rails.application.routes.draw do
  telegram_webhook TelegramWebhookController
  post "/github/webhook", to: "github_webhooks#create"
end

# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include TelegramBotEngine::SubscriberCommands
  # start!, stop!, help! are provided automatically.
  # No custom commands needed for DevOps — just broadcasting.
end

# app/controllers/github_webhooks_controller.rb
class GithubWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = JSON.parse(request.body.read)
    return head :ok unless payload["action"] == "completed"

    run = payload["workflow_run"]
    emoji = run["conclusion"] == "success" ? "✅" : "❌"
    repo = run["repository"]["name"]
    branch = run["head_branch"]

    TelegramBotEngine.broadcast(
      "#{emoji} *#{repo}* on branch *#{branch}*: _#{run['conclusion']}_",
      parse_mode: "Markdown"
    )

    head :ok
  end
end
```

---

## Example: Parking Detection App (bidirectional)

```ruby
# config/credentials.yml.enc
telegram:
  bot:
    token: "BOT_TOKEN_HERE"
    username: "parking_detect_bot"

# config/initializers/telegram_bot_engine.rb
TelegramBotEngine.configure do |config|
  config.allowed_usernames = %w[landovsky]
end

# config/routes.rb
Rails.application.routes.draw do
  telegram_webhook TelegramWebhookController

  authenticate :user, ->(u) { u.admin? } do
    mount TelegramBotEngine::Engine, at: "/telegram/admin"
  end
end

# app/controllers/telegram_webhook_controller.rb
class TelegramWebhookController < Telegram::Bot::UpdatesController
  include TelegramBotEngine::SubscriberCommands
  include Telegram::Bot::UpdatesController::CallbackQueryContext

  def park!(*args)
    zone = args.first || "default"
    new_mode = ParkingDetector.toggle_mode!(zone: zone)
    respond_with :message, text: "✅ Detection mode: *#{new_mode}*", parse_mode: "Markdown"
  end

  def status!(*)
    s = ParkingDetector.current_status
    respond_with :message,
      text: "📊 *Status*\nMode: `#{s.mode}`\nOccupied: #{s.occupied_count}",
      parse_mode: "Markdown"
  end

  def mute!(*args)
    minutes = (args.first || 30).to_i
    sub = TelegramBotEngine::Subscription.find_by(chat_id: chat["id"])
    sub&.update(metadata: sub.metadata.merge("muted_until" => minutes.minutes.from_now.iso8601))
    respond_with :message, text: "🔇 Muted for #{minutes} minutes"
  end

  # Callback query handler for inline keyboard buttons
  def ack_parking_callback_query(event_id = nil, *)
    ParkingEvent.find(event_id)&.acknowledge! if event_id
    answer_callback_query "Acknowledged!"
  end
end

# In the parking detection domain (Layer 3), when an event occurs:
class ParkingDetector
  def self.on_space_occupied(space)
    TelegramBotEngine.broadcast(
      "🚗 Space *#{space.name}* is now occupied",
      parse_mode: "Markdown",
      reply_markup: {
        inline_keyboard: [[
          { text: "✅ Acknowledge", callback_data: "ack_parking:#{space.last_event_id}" }
        ]]
      }
    )
  end

  def self.on_space_freed(space)
    TelegramBotEngine.broadcast(
      "🅿️ Space *#{space.name}* is now free",
      parse_mode: "Markdown"
    )
  end
end
```

---

## What comes from where

| Capability                          | Provided by        | Notes                                        |
|-------------------------------------|--------------------|----------------------------------------------|
| Telegram API client                 | `telegram-bot` gem | `Telegram.bot.send_message(...)` etc.        |
| Webhook ingestion                   | `telegram-bot` gem | `telegram_webhook` route helper              |
| Command routing (`/park` → `park!`) | `telegram-bot` gem | Method naming convention on controller       |
| Command argument parsing            | `telegram-bot` gem | `def park!(*args)` receives parsed args      |
| Reply helpers                       | `telegram-bot` gem | `respond_with`, `reply_with`, etc.           |
| Callback query routing              | `telegram-bot` gem | `CallbackQueryContext` module                |
| Session support                     | `telegram-bot` gem | Optional, backed by `ActiveSupport::Cache`   |
| Async message sending               | `telegram-bot` gem | `async: true` in bot config                  |
| Development poller                  | `telegram-bot` gem | `rake telegram:bot:poller`                   |
| Webhook rake tasks                  | `telegram-bot` gem | `rake telegram:bot:set_webhook`              |
| RSpec testing helpers               | `telegram-bot` gem | Matchers, dispatch helpers, stubs            |
| **Subscription persistence**        | **engine**         | `Subscription` model + migrations            |
| **User authorization/allowlist**    | **engine**         | `Authorizer` + `AllowedUser` model           |
| **`/start`, `/stop`, `/help`**      | **engine**         | `SubscriberCommands` concern                 |
| **`broadcast()` method**            | **engine**         | Iterates active subscriptions + delivery job |
| **`notify()` method**               | **engine**         | Direct message to specific chat_id           |
| **Auto-deactivation on block**      | **engine**         | `DeliveryJob` catches `Forbidden`            |
| **Admin UI**                        | **engine**         | Subscriptions + allowlist management         |

---

## Future Extensions (out of scope for v1)

Documented for awareness, explicitly **not** part of the initial implementation:

- **Topics/channels**: subscribers opt into specific notification topics. Would add a topics model and scoped broadcast: `TelegramBotEngine.broadcast("msg", topic: "hriste")`
- **Invite tokens**: generate one-time `t.me/bot?start=TOKEN` links for inviting users without pre-configuring their username in the allowlist
- **Mute-awareness in broadcast**: engine checks `muted_until` in subscription metadata before delivering, so mute logic doesn't need to live in the host app
- **Media messages**: broadcast images, documents, location pins
- **Group chat support**: current design is for private 1:1 chats with the bot; group chat semantics (multiple users in one chat_id) would need different subscription logic
- **Delivery logging**: persist message delivery status (sent, failed, blocked) for observability
- **Rate limiting**: built-in Telegram rate limit handling (30 msg/sec) with job throttling
