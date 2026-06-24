# 0001 — Multi-bot architecture for `telegram_bot_engine`

**Status:** Proposed (accepted direction; implementation not started).
**Date:** 2026-06-24.
**Supersedes:** the *"one bot per host app"* model in `../telegram_bot_engine_spec_v2.md` §Overview.
**Companion:** [`cross-session-coordination.md`](./cross-session-coordination.md) — how this repo's
session coordinates with the `devops-telegram` session.
**Origin:** decision recorded in `devops-telegram/artifacts/adr/0001-multi-bot-placement.md`.

---

## 1. Decision in one line

Multi-bot is **not a feature on top of this gem; it is the generalization *of* this gem.**
The bot-identity machinery belongs here. The host app keeps only what is keyed by an
**app source name** (GitHub / Flux / a `/notify` channel).

> **The rule.** Keyed by a *Telegram bot identity* → **gem**.
> Keyed by an *app source name* → **app**.

### Why it must be the gem (the load-bearing fact)

`TelegramBotEngine.broadcast` is the host app's **only** integration verb — every
notification path calls it and nothing else; the app owns **zero** subscriber/delivery
code. Inside the gem, `broadcast` (`lib/telegram_bot_engine.rb`) names `DeliveryJob` and
`Subscription` as hardcoded constants with no injection seam, and `DeliveryJob`
(`app/jobs/telegram_bot_engine/delivery_job.rb:9`) hardcodes `Telegram.bot.send_message`
— always the `:default` bot. The only two `Telegram.bot` references in the whole system
are that line plus `dashboard_controller.rb` (`Telegram.bot.username`).

So a host app cannot reach a second bot through the gem without either **bypassing** it
(`Telegram.bots[:assistant].send_message`) or **monkeypatching** it — both of which turn
the gem into half-used legacy. Making delivery bot-aware is a small, contained change, but
it can only be made **here**. "Small change" and "must be in the gem" are the same fact.

---

## 2. Scope: what moves into the gem

| # | Capability | Home | Notes |
|---|---|---|---|
| 1 | **Bots-as-data** — `Bot` model (name, slug, purpose, encrypted token, webhook_secret, active, default) | **Gem** | The gem's charter is "the persistence and management layer." A bot row is generic Telegram config — the next first-class entity beside `Subscription`/`AllowedUser`/`Event`. |
| 2 | **Client registry** — resolve `Telegram::Bot::Client` from a DB record at request time, cache, invalidate on save | **Gem** | Fills `telegram-bot`'s gap: `Telegram.bots` is boot-memoized (`@bots ||=`) and not built for runtime hot-add. |
| 3 | **Bot-aware delivery** — `broadcast(bot:)`, `notify(bot:)`, `DeliveryJob(bot_id, …)` | **Gem** | The load-bearing change above. |
| 7 | **Per-bot subscribers** — `bot_id` on subscriptions, unique index `(bot_id, chat_id)`, scoped broadcast | **Gem** | The current globally-unique `chat_id` index is a multi-bot *bug* on a gem-owned table. |
| 8 | **Per-bot allowlist** — `Authorizer.authorized?(username, bot:)`, per-bot `AllowedUser` | **Gem** | Generic auth plumbing on gem-owned models. |
| 5 | **Webhook registrar** — `setWebhook`/`deleteWebhook` with per-bot secret path + `secret_token` | **Gem** | Generic Telegram protocol, parameterized by an app-supplied `base_url`. |
| 6 | **Inbound dispatcher** — one endpoint, resolve `Bot` by webhook_secret, `controller.dispatch(bot.client, …)` | **Gem** | `telegram-bot`'s middleware already passes the bot *into* `dispatch`, so this is a small generalization. Needs the gem's `Bot` model. |
| 9 | **Bots admin UI** — CRUD, token entry/rotation, webhook status; per-bot scoping of existing screens | **Gem** | Extends the gem's existing ERB admin (which already shims api_only middleware). |
| **4** | **Routing** — source/channel (`github`/`flux`/`notify`-channel) → bot | **App** | The one piece whose *keys* are app vocabulary the gem must never learn. |
| — | Message builders, host wiring, `webhook_base_url`, encryption keys, token-storage policy | **App** | Stay in the app regardless of this decision. |

---

## 3. Public API contract (the integration surface)

> This section is the **contract** both sessions build against. Changes here require the
> coordination protocol (announce + update before merge).

### 3.1 `TelegramBotEngine::Bot`

```ruby
# table: telegram_bot_engine_bots
#   name           :string  not null
#   slug           :string  not null, unique           # stable handle, e.g. "default", "assistant"
#   purpose        :string                              # free text for the admin UI
#   token          :string  not null                    # encrypted at rest (see §6)
#   webhook_id     :string  not null, unique             # stable, NON-secret inbound routing id (URL path segment)
#   webhook_secret :string  not null, unique             # bearer secret_token — header ONLY, never in a URL/log
#   active         :boolean not null, default: true
#   default        :boolean not null, default: false     # exactly one row true
TelegramBotEngine::Bot.default        # => the default Bot (back-compat anchor)
TelegramBotEngine::Bot.resolve(slug)  # => Bot by slug
bot.client                            # => memoized Telegram::Bot::Client for this token
```

### 3.2 Registry

```ruby
TelegramBotEngine.client_for(bot)   # Telegram::Bot::Client, resolved from DB, cached by bot_id
                                    # cache invalidated on Bot save (token rotation safe)
```

### 3.3 Delivery (backward-compatible widening)

```ruby
TelegramBotEngine.broadcast(text, bot: Bot.default, **options)        # scopes subscribers to `bot`
TelegramBotEngine.notify(chat_id:, text:, bot: Bot.default, **options)
# DeliveryJob.perform(bot_id, chat_id, text, options)  # resolves client via registry, not Telegram.bot
```

`bot:` omitted ⇒ default bot ⇒ **today's behavior, unchanged.** All three `devops-telegram`
call sites keep working without edits.

### 3.4 Subscriptions (per-bot)

```ruby
# migration: add nullable bot_id (backfill → default bot); change unique index chat_id → (bot_id, chat_id)
TelegramBotEngine::Subscription.active.for_bot(bot)   # broadcast iterates this
```

### 3.5 Allowlist (per-bot)

```ruby
TelegramBotEngine::Authorizer.authorized?(username, bot: nil)  # bot: nil ⇒ global (today's behavior)
# AllowedUser gains a nullable bot_id (nil ⇒ applies to all bots)
```

### 3.6 Webhook registrar

```ruby
TelegramBotEngine::WebhookRegistrar.register(bot, base_url: TelegramBotEngine.config.webhook_base_url)
#   => bot.client.set_webhook(
#        url:          "#{base_url}#{config.webhook_mount_path}/#{bot.webhook_id}",  # NON-secret routing id
#        secret_token: bot.webhook_secret)                                           # secret stays in the header
TelegramBotEngine::WebhookRegistrar.remove(bot)   # => bot.client.delete_webhook
```

> **Security (the routing key is NOT the secret).** The URL path carries the non-secret
> `webhook_id`; the bearer `secret_token` is `webhook_secret` and travels only in the
> `X-Telegram-Bot-Api-Secret-Token` header. This prevents Rails' request/SQL logging (which
> records URL paths and bind params verbatim) from leaking the credential — a log reader
> learns only the routing id, never enough to forge an authenticated delivery.

- **Auto-(un)registration:** `Bot#after_save` registers (when `active?`) or removes (when
  not); `Bot#after_destroy` removes. Gated on `config.webhook_base_url.present? &&
  config.auto_register_webhooks` (default `true`). Failures are rescued and logged as a
  `webhook` / `register_failed` Event, so an admin save never 500s on a Telegram hiccup.
- **`setWebhook` is idempotent** (overwrites), so re-registering is always safe.

### 3.7 Inbound dispatcher

```ruby
# config/routes.rb (host app) — mount ONCE for ALL bots:
mount TelegramBotEngine::Dispatch, at: TelegramBotEngine.config.webhook_mount_path  # default "/telegram/bot"
```

`TelegramBotEngine::Dispatch` is a Rack endpoint. For `POST <mount>/:webhook_id` it:

1. resolves `bot = Bot.active.find_by(webhook_id: …)` (the non-secret path segment) → **404** if unknown;
2. validates the `X-Telegram-Bot-Api-Secret-Token` header `== bot.webhook_secret`
   (constant-time) → **403** on mismatch/absent (telegram-bot 0.16 does NOT — see §9);
3. exposes the Bot record as `request.env["telegram_bot_engine.bot"]`, then calls
   `config.dispatch_controller.dispatch(bot.client, request.request_parameters, request)` → **200**;
   → **400** on a malformed JSON body; **503** if `dispatch_controller` is unset.

**Answers to the host-wiring questions:**

- **(1) Replaces, but coexists during migration.** `Dispatch` is the *single* inbound
  endpoint for **all** bots including the default. It supersedes the per-bot
  `telegram_webhook` helper. Because `Dispatch` mounts at a *different* path than the
  helper's token-derived path, the two coexist with **no flag-day**: the default bot keeps
  flowing through the old route until you re-register it (step 2).
- **(2) Default-bot migration = one idempotent re-register.** Run
  `TelegramBotEngine::WebhookRegistrar.register(TelegramBotEngine::Bot.default, base_url:)`
  (or just save the active default once auto-registration is on). That points the default
  bot's webhook at `…/telegram/bot/<default.webhook_secret>`; then the old `telegram_webhook`
  route can be removed.
- **(3) Reuse your existing controller; one controller for all bots in v1.** Set
  `config.dispatch_controller = "TelegramWebhookController"` — your current
  `TelegramWebhookController < Telegram::Bot::UpdatesController` (which already
  `include`s `SubscriberCommands`) is the dispatch target unchanged; `dispatch(bot.client,
  update, request)` is the same signature the helper used. The bot is **parameterized**, not
  selected by controller: identity arrives via `bot.client` + `request.env[
  "telegram_bot_engine.bot"]`. `SubscriberCommands` reads that env Bot so inbound
  `/start`·`/stop` create/scope **that bot's** subscriptions (a chat that `/start`s the
  Assistant becomes an Assistant-owned subscriber). With no env Bot (e.g. the poller), it
  falls back to the default/nil convention — today's behavior, unchanged.

### 3.9 Host configuration (Phase 3 additions)

```ruby
TelegramBotEngine.configure do |c|
  c.webhook_base_url       = "https://devops-telegram.kopernici.cz" # required to register webhooks
  c.webhook_mount_path     = "/telegram/bot"                        # default; MUST match the Dispatch mount
  c.dispatch_controller    = "TelegramWebhookController"            # host UpdatesController incl. SubscriberCommands
  c.auto_register_webhooks = true                                  # default; gates Bot-save auto (un)registration
end
```

### 3.8 Admin

Gem adds a `bots` resource (CRUD + token rotation + webhook status) and scopes the existing
`subscriptions`/`allowlist`/`events` screens per bot. The dashboard becomes multi-bot
(replacing the single `Telegram.bot.username` call).

---

## 4. Backward-compatibility rules

- `bot:` always defaults to `Bot.default`.
- New columns are **nullable** with a default-bot fallback; a rolled-back gem version
  ignores them harmlessly.
- A **`Bot.default` seed** is created from the existing single-bot config/ENV so nothing
  breaks on first boot (`ensure_default!`).
- The gem's own RSpec suite must stay green at every step, *including* a regression test
  that the no-`bot:` path still targets the default bot.

---

## 5. Phased plan

> Scope is sized to the app's current need: the new "Assistant" bot is **outbound-only for
> v1** (door open to two-way later). So phases 0–1 are the v1 deliverable; phases 2–3 are
> deferred until a two-way bot is actually wanted.

| Phase | Repo | Deliverable | Ship |
|---|---|---|---|
| **0** | Gem | `Bot` model + registry + bot-aware `broadcast`/`notify`/`DeliveryJob` (caps 1,2,3). `bot:` defaults to default. `ensure_default!` seeds the default bot from existing config. | `0.4.0` |
| **1** | App | Source→bot **routing** table + editor; wire the Assistant bot as an **outbound-only** target; call `broadcast(bot: routed_bot)`. **← v1 done.** | app tag |
| **2** | Gem | Per-bot **subscribers** (cap 7) + per-bot **allowlist** (cap 8) + **bots admin** (cap 9). | `0.5.0` |
| **3** | Gem + App | **Webhook registrar** (5) + **inbound dispatcher** (6) → enables a *two-way* Assistant bot. | `0.6.0` + app tag |

Each phase follows the handshake in `cross-session-coordination.md`.

---

## 6. Token storage

- `Bot#token` is **encrypted at rest** via ActiveRecord Encryption (`encrypts :token`).
- Encryption **keys are an app-side prerequisite** — none are configured in `devops-telegram`
  today. Provisioning them (credentials + K8s secret) is app/ops work, independent of this gem.
- **Until keys are live**, seed `Bot` rows from ENV (`TELEGRAM_BOT_TOKEN`, and an
  `ASSISTANT_BOT_TOKEN` for v1) so multi-bot delivery can be built and tested without
  blocking on encryption. The browser-paste/token-rotation UX (the headline goal) lands
  once keys are provisioned. The API contract is identical either way.

---

## 7. Open decisions (carried forward)

- **Assistant bot: outbound-only vs two-way?** → *outbound-only for v1* (decided 2026-06-24,
  "not sure yet" → keep door open). Drives whether phases 2–3 are needed.
- **Subscribers: shared across bots vs per-bot?** → design assumes **per-bot** (`bot_id` on
  subscriptions); `bot: Bot.default` keeps single-bot apps unaffected.
- **One inbound dispatcher vs per-bot routes?** → recommend **one dispatcher** keyed by
  `webhook_secret` (§3.7).
- **Token at rest: DB-encrypted vs K8s secret?** → DB-encrypted is the end goal; ENV seed is
  the bridge (§6).

---

## 8. Testing

This repo already ships a real harness — `spec/dummy` app, factories
(`spec/factories/subscriptions.rb`, `allowed_users.rb`), and model/job/controller specs.
Extend it:

- Assert **"delivery picked the right bot"** against `Telegram.bots[bot_id].requests` using
  `telegram-bot`'s `ClientStub`/`stub_all!` (the seam multi-bot must exercise). A host-app
  mock of `TelegramBotEngine.broadcast` cannot verify this — it is why the test belongs here.
- Regression-guard the back-compat path: no `bot:` ⇒ default bot.
- Test the registry's cache invalidation on token rotation (stale-client trap).

---

## 9. Implementation notes / risks to verify during build

- `telegram-bot` 0.16 has **no `secret_token` validation** in its webhook middleware — the
  dispatcher (§3.7) must add the `X-Telegram-Bot-Api-Secret-Token` check.
- `Telegram.bots` is process-global and boot-memoized; the registry (§3.2) must not rely on
  `reset_bots` alone under concurrency — prefer per-bot `Telegram::Bot::Client.new(token)`
  resolution keyed by `bot_id`.
- The published gem artifact strips `spec/`; the **repo** has the full suite. Develop here,
  not against the installed gem.
- Production applies migrations via `db:prepare` on a **single-replica SQLite** pod; keep all
  schema changes additive/nullable (a tag rollback reverts code but not an applied migration).
