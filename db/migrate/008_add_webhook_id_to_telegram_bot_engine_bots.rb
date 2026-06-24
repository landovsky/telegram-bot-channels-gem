# frozen_string_literal: true

require "securerandom"

# Decouple the inbound ROUTING key from the bearer SECRET (security hardening, docs/0001
# §3.6/§3.7). Previously the webhook URL embedded `webhook_secret`, which Rails logs verbatim
# in request lines and SQL binds — leaking the secret_token to any log reader. `webhook_id` is
# a stable, NON-secret public id that goes in the URL path; `webhook_secret` now lives ONLY in
# the X-Telegram-Bot-Api-Secret-Token header. Additive + backfilled; uses update_columns via an
# anonymous model so no Bot callbacks/validations fire during the migration.
class AddWebhookIdToTelegramBotEngineBots < ActiveRecord::Migration[7.0]
  def up
    add_column :telegram_bot_engine_bots, :webhook_id, :string

    seam = Class.new(ActiveRecord::Base) { self.table_name = "telegram_bot_engine_bots" }
    seam.reset_column_information
    seam.where(webhook_id: nil).find_each do |row|
      row.update_columns(webhook_id: SecureRandom.hex(16))
    end

    change_column_null :telegram_bot_engine_bots, :webhook_id, false
    add_index :telegram_bot_engine_bots, :webhook_id, unique: true
  end

  def down
    remove_index :telegram_bot_engine_bots, :webhook_id
    remove_column :telegram_bot_engine_bots, :webhook_id
  end
end
