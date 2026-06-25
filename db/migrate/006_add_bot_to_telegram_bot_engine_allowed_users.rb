# frozen_string_literal: true

# Per-bot allowlist (docs/0001 §3.5): an AllowedUser may be scoped to a bot. A nil bot_id
# is a GLOBAL allow entry that applies to every bot — exactly today's behavior, so existing
# rows (all nil) keep authorizing as before. Additive + nullable.
#
# Partial unique index on (username WHERE bot_id IS NULL) preserves the duplicate guard the
# old global unique(username) index gave global entries (NULLs are distinct in the composite
# index). Explicit up/down so rollback restores the original UNIQUE(username) faithfully.
class AddBotToTelegramBotEngineAllowedUsers < ActiveRecord::Migration[7.0]
  GLOBAL_UNIQUE = "index_tbe_allowed_users_on_username_global"

  def up
    add_column :telegram_bot_engine_allowed_users, :bot_id, :bigint
    add_index :telegram_bot_engine_allowed_users, :bot_id

    remove_index :telegram_bot_engine_allowed_users, :username # drop the global UNIQUE(username)
    add_index :telegram_bot_engine_allowed_users, :username    # keep a non-unique lookup index
    add_index :telegram_bot_engine_allowed_users, %i[bot_id username], unique: true
    add_index :telegram_bot_engine_allowed_users, :username, unique: true,
              where: "bot_id IS NULL", name: GLOBAL_UNIQUE
  end

  def down
    remove_index :telegram_bot_engine_allowed_users, name: GLOBAL_UNIQUE
    remove_index :telegram_bot_engine_allowed_users, column: %i[bot_id username]
    remove_index :telegram_bot_engine_allowed_users, :username
    add_index :telegram_bot_engine_allowed_users, :username, unique: true # restore original guard
    remove_index :telegram_bot_engine_allowed_users, :bot_id
    remove_column :telegram_bot_engine_allowed_users, :bot_id
  end
end
