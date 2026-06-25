# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the gem is pre-1.0, minor bumps may widen the API in backward-compatible ways.

## [0.6.1] - 2026-06-25

### Added
- **Bot column in the events admin table** — the `/telegram/admin/events` table now shows the bot name per row (mapped from `event.bot_id`), instead of leaving bot identity buried in the Details JSON. Command events with no bot (e.g. `start`/`stop`/`help`) render `-`.

### Changed
- The redundant `bot` key is dropped from the events Details JSON column now that the bot is shown in its own column.

## [0.6.0] - 2026-06-25

### Added
- **Inbound dispatcher** (`TelegramBotEngine::Dispatch`) — a single Rack endpoint, mounted once at `config.webhook_mount_path`, that routes `POST <mount>/:webhook_id` to the resolved bot's `UpdatesController`. Validates the `X-Telegram-Bot-Api-Secret-Token` header with a constant-time compare (which `telegram-bot` 0.16 does not do).
- **Webhook registrar** (`TelegramBotEngine::WebhookRegistrar`) — registers/removes each bot's Telegram webhook with a per-bot secret; auto-(un)registers on `Bot` save/destroy when `config.webhook_base_url` is set.
- Configuration keys: `webhook_base_url`, `webhook_mount_path`, `dispatch_controller`, `auto_register_webhooks`.
- `webhook_id` (non-secret routing id, carried in the URL) and `webhook_secret` (bearer credential, header only) on `Bot`, with backfill for existing rows.

### Fixed
- `DeliveryJob` now inherits an engine-local `TelegramBotEngine::ApplicationJob` instead of the host app's `::ApplicationJob`, so the engine installs cleanly into API-only or non-standard hosts that don't define one.

## [0.5.0] - 2026-06-25

### Added
- **Per-bot subscribers and allowlist** — `Subscription` and `AllowedUser` are scoped to a bot via `bot_id` and the `for_bot` scope; composite and partial-unique indexes keep per-bot and global rows distinct.
- **Bots admin UI** — index / new / edit, plus a bot column across the subscriptions, events, and allowlist views.
- Bot-aware `Authorizer` and `SubscriberCommands` so inbound `/start`·`/stop` scope to the bot the update arrived for.

## [0.4.0] - 2026-06-25

### Added
- **`Bot` model** (`telegram_bot_engine_bots`) — a first-class, persisted Telegram bot identity, with an auto-seeded default-bot anchor for backward compatibility.
- **Client `Registry`** — a per-bot `Telegram::Bot::Client` cache keyed by bot id (token-rotation safe).
- **Bot-aware delivery** — `broadcast` and `notify` accept a `bot:` argument and deliver through that bot's own client; omitting `bot:` targets the default bot, preserving existing single-bot behavior.

## [0.3.4] and earlier

Single-bot baseline: subscriber management, authorization, broadcasting, an event log, and an admin UI on top of the [`telegram-bot`](https://github.com/telegram-bot-rb/telegram-bot) gem.

[0.6.0]: https://github.com/landovsky/telegram-bot-channels-gem/releases/tag/v0.6.0
[0.5.0]: https://github.com/landovsky/telegram-bot-channels-gem/releases/tag/v0.5.0
[0.4.0]: https://github.com/landovsky/telegram-bot-channels-gem/releases/tag/v0.4.0
