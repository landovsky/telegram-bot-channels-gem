# frozen_string_literal: true

# Runs the REAL migration files (not the hand-maintained spec_helper schema) against a
# fresh in-memory SQLite database, asserting both the forward end-state and a faithful
# up -> down -> up round-trip. Invoked as a subprocess from migrations_spec.rb so it gets
# a clean, isolated connection that cannot disturb the main suite's shared connection.
#
# Exits non-zero (raising) on the first failed assertion; prints MIGRATION_CHECK_OK on success.

require "active_record"

ROOT = File.expand_path("../..", __dir__)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false

MIGRATIONS = {
  "001_create_telegram_bot_engine_subscriptions"     => "CreateTelegramBotEngineSubscriptions",
  "002_create_telegram_bot_engine_allowed_users"     => "CreateTelegramBotEngineAllowedUsers",
  "003_create_telegram_bot_engine_events"            => "CreateTelegramBotEngineEvents",
  "004_create_telegram_bot_engine_bots"              => "CreateTelegramBotEngineBots",
  "005_add_bot_to_telegram_bot_engine_subscriptions" => "AddBotToTelegramBotEngineSubscriptions",
  "006_add_bot_to_telegram_bot_engine_allowed_users" => "AddBotToTelegramBotEngineAllowedUsers",
  "007_add_bot_to_telegram_bot_engine_events"        => "AddBotToTelegramBotEngineEvents",
  "008_add_webhook_id_to_telegram_bot_engine_bots"   => "AddWebhookIdToTelegramBotEngineBots"
}.each_with_object({}) do |(file, klass), h|
  require File.join(ROOT, "db", "migrate", file)
  h[klass] = Object.const_get(klass)
end

def conn = ActiveRecord::Base.connection

def assert(cond, msg)
  raise "ASSERTION FAILED: #{msg}" unless cond
end

def index(table, name)
  conn.indexes(table).find { |i| i.name == name }
end

def unique_violation?
  yield
  false
rescue ActiveRecord::StatementInvalid
  true
end

# --- forward: apply base tables, seed a legacy bot, then the Phase 2/3 migrations --------
base = %w[
  CreateTelegramBotEngineSubscriptions CreateTelegramBotEngineAllowedUsers
  CreateTelegramBotEngineEvents CreateTelegramBotEngineBots
]
phase2_3 = %w[
  AddBotToTelegramBotEngineSubscriptions AddBotToTelegramBotEngineAllowedUsers
  AddBotToTelegramBotEngineEvents AddWebhookIdToTelegramBotEngineBots
]

base.each { |k| MIGRATIONS[k].migrate(:up) }

# A bot row created BEFORE webhook_id existed — migration 008 must backfill it.
conn.execute(
  "INSERT INTO telegram_bot_engine_bots (name, slug, token, webhook_secret, active, \"default\", created_at, updated_at) " \
  "VALUES ('Legacy', 'legacy', 'tok', 'sek', 1, 0, datetime('now'), datetime('now'))"
)

phase2_3.each { |k| MIGRATIONS[k].migrate(:up) }

legacy_whid = conn.select_value("SELECT webhook_id FROM telegram_bot_engine_bots WHERE slug = 'legacy'")
assert !legacy_whid.to_s.empty?, "migration 008 backfills webhook_id on a pre-existing (legacy) bot"

subs = "telegram_bot_engine_subscriptions"
allow = "telegram_bot_engine_allowed_users"

assert conn.column_exists?(subs, :bot_id), "subscriptions.bot_id added"
composite = index(subs, "index_telegram_bot_engine_subscriptions_on_bot_id_and_chat_id")
assert composite&.unique, "(bot_id, chat_id) is unique"
partial = index(subs, "index_tbe_subscriptions_on_chat_id_default_bot")
assert partial&.unique, "partial unique on chat_id (default-bot rows) exists"
chat_idx = conn.indexes(subs).select { |i| i.columns == ["chat_id"] && i.name != "index_tbe_subscriptions_on_chat_id_default_bot" }
assert chat_idx.any? && chat_idx.none?(&:unique), "global chat_id index is now non-unique"

au_composite = index(allow, "index_telegram_bot_engine_allowed_users_on_bot_id_and_username")
assert au_composite&.unique, "(bot_id, username) is unique"
au_partial = index(allow, "index_tbe_allowed_users_on_username_global")
assert au_partial&.unique, "partial unique on username (global rows) exists"

# --- behavior: the partial + composite indexes actually guard the right rows ---------
ins = ->(bot_id, chat_id) { conn.execute("INSERT INTO #{subs} (bot_id, chat_id, active, created_at, updated_at) VALUES (#{bot_id || 'NULL'}, #{chat_id}, 1, datetime('now'), datetime('now'))") }
ins.call(nil, 555)
ins.call(1, 555)
ins.call(2, 555)
assert conn.select_value("SELECT COUNT(*) FROM #{subs}").to_i == 3, "same chat coexists under nil/bot1/bot2"
assert unique_violation? { ins.call(nil, 555) }, "duplicate (NULL, 555) rejected by the default-bot partial unique index"
assert unique_violation? { ins.call(1, 555) }, "duplicate (1, 555) rejected by the composite unique index"

au_ins = ->(bot_id, name) { conn.execute("INSERT INTO #{allow} (bot_id, username, created_at, updated_at) VALUES (#{bot_id || 'NULL'}, '#{name}', datetime('now'), datetime('now'))") }
au_ins.call(nil, "tom")
au_ins.call(5, "tom")
assert unique_violation? { au_ins.call(nil, "tom") }, "duplicate global username rejected by the global partial unique index"
assert unique_violation? { au_ins.call(5, "tom") }, "duplicate (5, tom) rejected by the composite unique index"

# --- round-trip: down must FAITHFULLY restore the original UNIQUE(chat_id/username) ---
# Clear the per-bot probe rows first: they are only unique per (bot_id, X), so restoring a
# GLOBAL unique index over them would correctly fail. The round-trip tests schema reversal,
# not data migration. (In production migrations are never rolled back — docs/0001 §9.)
conn.execute("DELETE FROM #{subs}")
conn.execute("DELETE FROM #{allow}")

MIGRATIONS["AddBotToTelegramBotEngineAllowedUsers"].migrate(:down)
MIGRATIONS["AddBotToTelegramBotEngineSubscriptions"].migrate(:down)

assert !conn.column_exists?(subs, :bot_id), "rollback drops subscriptions.bot_id"
restored = conn.indexes(subs).select { |i| i.columns == ["chat_id"] }
assert restored.size == 1 && restored.first.unique, "rollback restores the ORIGINAL unique chat_id index (not left non-unique)"
au_restored = conn.indexes(allow).select { |i| i.columns == ["username"] }
assert au_restored.size == 1 && au_restored.first.unique, "rollback restores the ORIGINAL unique username index"

# --- re-apply: up after down works (no leftover index / column collisions) -----------
MIGRATIONS["AddBotToTelegramBotEngineSubscriptions"].migrate(:up)
MIGRATIONS["AddBotToTelegramBotEngineAllowedUsers"].migrate(:up)
assert index(subs, "index_telegram_bot_engine_subscriptions_on_bot_id_and_chat_id")&.unique, "re-applied composite unique after round-trip"
assert index(subs, "index_tbe_subscriptions_on_chat_id_default_bot")&.unique, "re-applied partial unique after round-trip"

puts "MIGRATION_CHECK_OK"
