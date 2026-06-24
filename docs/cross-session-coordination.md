# Cross-session coordination: `telegram_bot_engine` ⇆ `devops-telegram`

**Status:** Active requirement for the multi-bot effort.
**Date:** 2026-06-24.

Multi-bot spans **two repos**, so it is built by **two Claude Code sessions** that must
coordinate. This document is the contract for *how* they work together. It is referenced
(and its hard requirements restated) by:

- Gem side: [`docs/0001-multi-bot-architecture.md`](./0001-multi-bot-architecture.md) (this repo)
- App side: `artifacts/adr/0001-multi-bot-placement.md` and `artifacts/multi-bot-ui-handoff.md`
  (in `devops-telegram`)

---

## Why two sessions

The decision (see ADR-0001 in `devops-telegram`) is a **gem-weighted hybrid**: the
bot-identity machinery lives in this gem; the app keeps only its source→bot **routing**,
its message builders, and host wiring. Neither half ships value alone — the gem's new
`broadcast(bot:)` is useless until the app routes to it, and the app's routing is useless
until the gem can deliver through a chosen bot. So the work is **co-developed**, not
handed off in one direction.

| | **Gem session** — `telegram-bot-channels-gem` | **App session** — `devops-telegram` |
|---|---|---|
| Owns | `Bot` model, client registry, bot-aware delivery, per-bot subscribers/allowlist, webhook registrar, inbound dispatcher, bots admin, gem tests, gem releases | Source→bot routing table + editor, `Github`/`Flux` message builders, webhook controllers, `/notify`, host config (`webhook_base_url`, encryption keys), mount points, integration tests, app releases |
| Branch | `feature/multi-bot` | `feature/multi-bot` |
| Ships via | rubygems publish (`0.4.0`, …) | git tag `v*.*.*` → Flux |

---

## The integration contract

The **single integration surface** is the gem's public API, defined in
[`0001-multi-bot-architecture.md` §"Public API contract"](./0001-multi-bot-architecture.md).
That section is the source of truth both sessions build against.

**Hard requirements (both sessions):**

1. **No unilateral API changes.** Any change to the public API contract MUST be written
   into `0001-multi-bot-architecture.md` §API *and announced to the other session*
   (see Messaging) before it is merged.
2. **Backward compatibility is mandatory at every step.** `bot:` defaults to
   `Bot.default`; new DB columns are nullable with a default-bot fallback; **every existing
   `devops-telegram` call site must stay green without edits** after each gem change. The
   three current call sites are `github_webhooks_controller.rb`, `flux_webhooks_controller.rb`,
   `notifications_controller.rb` — all call `TelegramBotEngine.broadcast(text, parse_mode:)`.
3. **The app never reaches into gem internals.** No monkeypatching / constant-shadowing of
   `DeliveryJob`, `broadcast`, `Subscription`, or `Authorizer`. The app consumes only the
   documented public API. (This is the whole point of choosing gem-home — see ADR-0001.)
4. **Gem-owned tables get gem-owned migrations.** Schema changes to
   `telegram_bot_engine_*` tables ship from this gem via
   `telegram_bot_engine:install:migrations`. The app re-runs that task after each gem bump.
   (Avoids the "code references `bot_id` but the column was never copied in" boot crash.)

---

## Development wiring (`path:` ref)

So the app can build and integration-test against **unreleased** gem code without
publishing, `devops-telegram` references this repo locally **during development only**:

```ruby
# devops-telegram/Gemfile — DEV ONLY, do not commit to a release tag
gem "telegram_bot_engine", path: "/home/tomas/git/telegram-bot-channels-gem"
```

- `bundle install` then points the app at the working tree of this repo.
- The app session works against the gem's `feature/multi-bot` branch.
- ⚠️ A `path:` ref can **never** reach production: prod ships only on a `v*.*.*` app tag
  built from a `Gemfile.lock` pinned to a **published** rubygems version. So the `path:`
  line is reverted (and `Gemfile.lock` re-pinned to the new published version) before the
  app cuts a release tag.

---

## Messaging between sessions

Use the **`msg` skill** to talk to the other session. Inbound messages arrive prefixed
`[MSG from <label>]`. Send a message when you:

- **change the API contract** (requirement #1 above),
- **finish a phase** and it's ready for the other side to integrate,
- **hit an integration failure** the other side must fix,
- **publish a gem version** the app should bump to.

Keep messages short and reference the phase + the contract section.

---

## Phase handshake & release flow

Phases are defined in `0001-multi-bot-architecture.md` §"Phased plan". For each phase:

1. **Gem session** implements the phase on `feature/multi-bot`, keeps the gem's own RSpec
   suite green, and updates §API if the surface changed.
2. **Gem → App** message: "Phase N ready on `feature/multi-bot` (`path:`-installable);
   API §X added `broadcast(bot:)`…".
3. **App session** integrates against the `path:` gem, adds its routing/wiring, runs the
   app suite, and exercises it end-to-end.
4. **App → Gem** message: green ✅ (or red ❌ with the failure).
5. **Release (only when a phase is green end-to-end):**
   gem publishes `X.Y.0` to rubygems → app reverts the `path:` line and bumps
   `Gemfile.lock` to `X.Y.0` → app re-runs `telegram_bot_engine:install:migrations` →
   app cuts a `v*.*.*` tag → Flux deploys.

**Inner-loop rule:** publish to rubygems **once per phase/milestone**, not per iteration —
the `path:` ref carries all intermediate work. (The same-day `0.3.1→0.3.4` republish thrash
in this repo's history is exactly what this rule prevents.)
