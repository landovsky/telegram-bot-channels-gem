# frozen_string_literal: true

# Per-bot subscribers (docs/0001 §3.4): a chat can now subscribe to more than one bot,
# so global chat_id uniqueness becomes (bot_id, chat_id) uniqueness.
#
# Additive + rollback-safe: bot_id is nullable and there is NO data backfill. Back-compat
# is handled at the read layer (Subscription.for_bot(default_bot) folds nil-bot_id rows in),
# so a rolled-back gem that knows nothing about bot_id still reads every row (docs/0001 §9).
#
# A partial unique index on (chat_id WHERE bot_id IS NULL) preserves the duplicate guard the
# old global unique index gave the pre-multi-bot (default-bot) population — composite unique
# indexes treat NULL bot_id as distinct, so that set would otherwise lose DB-level protection.
#
# Explicit up/down so a rollback faithfully restores the original UNIQUE(chat_id) index
# instead of silently leaving it non-unique (the default `change` inverse would).
class AddBotToTelegramBotEngineSubscriptions < ActiveRecord::Migration[7.0]
  DEFAULT_BOT_UNIQUE = "index_tbe_subscriptions_on_chat_id_default_bot"

  def up
    add_column :telegram_bot_engine_subscriptions, :bot_id, :bigint
    add_index :telegram_bot_engine_subscriptions, :bot_id

    remove_index :telegram_bot_engine_subscriptions, :chat_id # drop the global UNIQUE(chat_id)
    add_index :telegram_bot_engine_subscriptions, :chat_id    # keep a non-unique lookup index
    add_index :telegram_bot_engine_subscriptions, %i[bot_id chat_id], unique: true
    add_index :telegram_bot_engine_subscriptions, :chat_id, unique: true,
              where: "bot_id IS NULL", name: DEFAULT_BOT_UNIQUE
  end

  def down
    remove_index :telegram_bot_engine_subscriptions, name: DEFAULT_BOT_UNIQUE
    remove_index :telegram_bot_engine_subscriptions, column: %i[bot_id chat_id]
    remove_index :telegram_bot_engine_subscriptions, :chat_id
    add_index :telegram_bot_engine_subscriptions, :chat_id, unique: true # restore original guard
    remove_index :telegram_bot_engine_subscriptions, :bot_id
    remove_column :telegram_bot_engine_subscriptions, :bot_id
  end
end
