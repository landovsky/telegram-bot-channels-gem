# Gap Analysis: Spec vs Implementation

**Source spec**: `telegram_bot_engine_spec_v2.md`
**Date**: 2026-02-25

---

## How to read this document

Every gap is triaged into one of two categories:

| Category | Meaning |
|---|---|
| **Oversight** | The implementation missed or diverged from the spec in a way that appears unintentional. These should be fixed to match the spec. |
| **Design Decision** | The implementation chose a valid alternative to what the spec describes. These warrant a conscious keep-or-change decision, but are not necessarily wrong. |

Each item includes the spec's stated intent so the fix can be made with confidence.

---

## Category 1: Oversights (should be fixed)

### 1.1 `stop!` response text is missing emoji

| | Detail |
|---|---|
| **File** | `lib/telegram_bot_engine/subscriber_commands.rb:35` |
| **Spec says** | `"👋 You've been unsubscribed. Send /start to resubscribe."` |
| **Implementation has** | `"You've been unsubscribed. Send /start to resubscribe."` |
| **Severity** | Low — cosmetic, but intentionally specified |
| **Intent** | The spec wants a friendly, emoji-prefixed farewell message consistent with the emoji usage in `help!` and the example host-app commands. |
| **Fix** | Add the `👋` emoji prefix to the string. |

### 1.2 `help!` response is missing emoji, Markdown formatting, and `parse_mode`

| | Detail |
|---|---|
| **File** | `lib/telegram_bot_engine/subscriber_commands.rb:39-41` |
| **Spec says** | `respond_with :message, text: "📋 *Available Commands*\n\n#{available_commands_text}", parse_mode: "Markdown"` |
| **Implementation has** | `respond_with :message, text: "Available Commands\n\n#{available_commands_text}"` |
| **Severity** | Medium — the user sees plain text instead of bold-formatted text in Telegram |
| **Intent** | The spec wants the help output to render as a Markdown-formatted message in Telegram with a bold title and clipboard emoji, matching the visual style of the other built-in commands. |
| **Fix** | Update the text to include `"📋 *Available Commands*\n\n#{available_commands_text}"` and add `parse_mode: "Markdown"` to the `respond_with` call. |

### 1.3 `metadata` column uses `json` instead of `jsonb`

| | Detail |
|---|---|
| **File** | `db/migrate/001_create_telegram_bot_engine_subscriptions.rb:11` |
| **Spec says** | Column type is `jsonb` ("Flexible storage for host app use") |
| **Implementation has** | `t.json :metadata, default: {}` |
| **Severity** | Medium — affects production PostgreSQL users |
| **Intent** | The spec explicitly calls for `jsonb`, which on PostgreSQL enables binary storage, GIN indexing, and containment operators (`@>`, `?`, `?&`). This matters for the future extensions the spec mentions (e.g., mute-awareness checking `muted_until` in metadata, topic subscriptions). Using plain `json` stores text and disallows these queries. |
| **Fix** | Change `t.json` to `t.jsonb` in the migration. Note: SQLite (used in tests) doesn't distinguish between the two, so tests pass either way — this gap is invisible in the test suite. |

### 1.4 `DeliveryJob` inherits from `ActiveJob::Base` instead of `ApplicationJob`

| | Detail |
|---|---|
| **File** | `app/jobs/telegram_bot_engine/delivery_job.rb:4` |
| **Spec says** | `class DeliveryJob < ApplicationJob` |
| **Implementation has** | `class DeliveryJob < ActiveJob::Base` |
| **Severity** | Medium — affects integration with host app job infrastructure |
| **Intent** | The Rails convention since Rails 5+ is for all jobs to inherit from `ApplicationJob`, which itself inherits from `ActiveJob::Base`. The spec follows this convention. `ApplicationJob` is the standard insertion point for shared job behavior in the host app (retry policies, error reporting, logging, instrumentation). By inheriting from `ActiveJob::Base` directly, the engine's delivery job bypasses any host-app-level job customizations. |
| **Fix** | Change `ActiveJob::Base` to `ApplicationJob`. If the engine needs its own base job class (to avoid depending on the host app's `ApplicationJob`), create `TelegramBotEngine::ApplicationJob < ActiveJob::Base` and inherit from that — but the spec doesn't call for this. |

### 1.5 `Authorizer.resolve_allowed_usernames` is not actually private

| | Detail |
|---|---|
| **File** | `lib/telegram_bot_engine/authorizer.rb:12-14` |
| **Spec says** | The method is under `private` and defined as `def self.resolve_allowed_usernames` |
| **Implementation has** | Same pattern — `private` followed by `def self.resolve_allowed_usernames` |
| **Severity** | Low — API leaks an internal method |
| **Intent** | Both spec and implementation share this Ruby gotcha: `private` only affects instance methods, not `def self.` class methods. The intent is clearly to make this an internal-only method. The method is callable externally as `TelegramBotEngine::Authorizer.resolve_allowed_usernames`. |
| **Fix** | Use `private_class_method :resolve_allowed_usernames` after the method definition, or restructure using `class << self; private; def resolve_allowed_usernames; ...; end; end`. Note: this is a bug in the spec too, but the spec's intent is clear. |

### 1.6 Missing `README.md`

| | Detail |
|---|---|
| **Spec says** | File structure lists `README.md` at the project root |
| **Gemspec** | `spec.files` includes `"README.md"` in its glob list |
| **Implementation has** | No `README.md` file exists |
| **Severity** | Medium — gem packaging will silently omit it, and users get no documentation |
| **Intent** | Standard gem practice. The spec's file structure shows it as a top-level file. |
| **Fix** | Create a `README.md` with installation, configuration, and usage instructions (much of which can be derived from the spec document itself). |

### 1.7 Missing `LICENSE` file

| | Detail |
|---|---|
| **Gemspec** | `spec.license = "MIT"` and `spec.files` includes `"LICENSE"` |
| **Implementation has** | No `LICENSE` file exists |
| **Severity** | Low — the gemspec declares MIT but there's no license text |
| **Fix** | Add a standard MIT `LICENSE` file. |

---

## Category 2: Design Decisions (keep or change consciously)

### 2.1 No separate `Broadcaster` service class

| | Detail |
|---|---|
| **Spec architecture diagram** | Lists `Services: - Broadcaster - Authorizer - DeliveryJob` |
| **Spec implementation section** | Shows `broadcast` and `notify` as `def self.` methods directly on the `TelegramBotEngine` module |
| **Implementation has** | `broadcast` and `notify` as class methods on `TelegramBotEngine` (matching the spec's implementation section) |
| **Assessment** | The spec has an internal inconsistency: the architecture diagram implies a `Broadcaster` service object, but the implementation section shows module-level methods. The implementation follows the implementation section, which is the more authoritative of the two. |
| **Recommendation** | Keep as-is. The current approach is simpler and the public API (`TelegramBotEngine.broadcast(...)`) is clean. If a `Broadcaster` class is ever needed (e.g., for topic-scoped broadcasting in future), it can be extracted then. Optionally, update the architecture diagram in the spec to say "Broadcast (module methods)" instead of "Broadcaster". |

### 2.2 Admin layout uses Tailwind CDN instead of inline CSS

| | Detail |
|---|---|
| **Spec says** | "server-rendered ERB with minimal inline CSS — no asset pipeline dependency" |
| **Implementation has** | `<script src="https://cdn.tailwindcss.com">` in the layout, with Tailwind utility classes throughout all views |
| **Assessment** | The implementation satisfies "no asset pipeline dependency" but uses CDN-loaded Tailwind rather than inline `style=""` attributes. The result is a much better-looking admin UI than inline CSS would produce. The tradeoff is a runtime CDN dependency — if the CDN is unreachable (air-gapped environments, CDN outage), the admin UI will be unstyled. |
| **Recommendation** | Likely keep. The Tailwind CDN approach is practical and produces a professional UI. If offline/air-gap support matters, consider bundling a minimal CSS file within the engine. Update the spec wording to say "Tailwind CSS via CDN" instead of "minimal inline CSS". |

### 2.3 Extra named `dashboard` route

| | Detail |
|---|---|
| **Spec routes table** | Shows only `GET /` for the dashboard |
| **Implementation has** | Both `root to: "dashboard#show"` AND `get "dashboard", to: "dashboard#show", as: :dashboard` |
| **Assessment** | The extra route provides a named helper (`admin_dashboard_path`) used in the navigation, allowlist controller redirect, and view links. Without it, the code would need to use `admin_root_path` everywhere, which is less descriptive. |
| **Recommendation** | Keep. The extra route is a practical addition that makes the code more readable. Update the spec's routes table to include it. |

### 2.4 Routes use `scope` instead of `namespace`

| | Detail |
|---|---|
| **Spec** | Shows routes under an `admin` scope (doesn't specify the exact routing DSL) |
| **Implementation** | `scope module: :admin, as: :admin do ... end` |
| **Assessment** | This is the correct Rails approach for engine routes where you want `/subscriptions` (not `/admin/subscriptions`) under the engine mount point, while still resolving to `Admin::` controllers. The URL structure matches the spec's route table. |
| **Recommendation** | Keep as-is. This is correct. |

---

## Summary Table

| # | Gap | Category | Severity | Fix Effort |
|---|---|---|---|---|
| 1.1 | `stop!` missing `👋` emoji | Oversight | Low | Trivial |
| 1.2 | `help!` missing emoji, bold, `parse_mode` | Oversight | Medium | Trivial |
| 1.3 | `metadata` column `json` vs `jsonb` | Oversight | Medium | Small (migration change) |
| 1.4 | `DeliveryJob` base class `ActiveJob::Base` vs `ApplicationJob` | Oversight | Medium | Trivial |
| 1.5 | `resolve_allowed_usernames` not actually private | Oversight | Low | Trivial |
| 1.6 | Missing `README.md` | Oversight | Medium | Moderate (content writing) |
| 1.7 | Missing `LICENSE` file | Oversight | Low | Trivial |
| 2.1 | No separate `Broadcaster` class | Design Decision | N/A | Keep, update spec diagram |
| 2.2 | Tailwind CDN vs inline CSS | Design Decision | N/A | Keep, update spec wording |
| 2.3 | Extra named dashboard route | Design Decision | N/A | Keep, update spec routes |
| 2.4 | `scope` vs `namespace` routing | Design Decision | N/A | Keep as-is |

---

## Spec-Implementation Alignment (confirmed correct)

The following areas were verified to match between spec and implementation:

- **Configuration DSL** — all four `attr_accessor` fields, defaults, `configure` block, `reset_config!`
- **Authorizer logic** — nil/Array/Proc/:database resolution, case-insensitive comparison
- **SubscriberCommands concern** — `before_action :authorize_user!`, `start!` find-or-initialize + save, `stop!` deactivation, command auto-detection from public `!` methods
- **broadcast/notify API** — `find_each` + `perform_later` pattern, keyword arguments
- **DeliveryJob** — queue, retry policy, `Telegram::Bot::Forbidden` handling, subscription deactivation
- **Subscription model** — table name, scope, validations
- **AllowedUser model** — table name, validations
- **Migration schema** — all columns, types (except jsonb), indexes, null constraints
- **Admin controllers** — BaseController admin check, DashboardController stats, SubscriptionsController CRUD, AllowlistController database-mode guard
- **Admin views** — dashboard stats cards + bot link, subscriptions table with toggle/delete, allowlist form + table
- **Engine isolation** — `isolate_namespace`, rspec generator config
- **Gemspec** — name, dependencies (`rails >= 7.0`, `telegram-bot ~> 0.16`), Ruby version, file globs
