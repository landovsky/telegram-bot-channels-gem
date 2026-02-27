# frozen_string_literal: true

class CreateTelegramBotEngineEvents < ActiveRecord::Migration[7.0]
  def adapter_type
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql") ? :jsonb : :json
  end

  def change
    create_table :telegram_bot_engine_events do |t|
      t.string :event_type, null: false
      t.string :action, null: false
      t.bigint :chat_id
      t.string :username
      t.column :details, adapter_type, default: {}
      t.datetime :created_at, null: false
    end

    add_index :telegram_bot_engine_events, :event_type
    add_index :telegram_bot_engine_events, :created_at
    add_index :telegram_bot_engine_events, :chat_id
  end
end
