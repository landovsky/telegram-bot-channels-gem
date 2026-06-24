# frozen_string_literal: true

# Per-bot event log (docs/0001 §3.8): tag delivery events with the bot that produced
# them so the events admin screen can be scoped per bot. Nullable + additive; command
# events (start/stop/help) stay nil until the inbound dispatcher knows the bot (Phase 3).
class AddBotToTelegramBotEngineEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :telegram_bot_engine_events, :bot_id, :bigint
    add_index :telegram_bot_engine_events, :bot_id
  end
end
