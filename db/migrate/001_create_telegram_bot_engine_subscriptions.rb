# frozen_string_literal: true

class CreateTelegramBotEngineSubscriptions < ActiveRecord::Migration[7.0]
  def adapter_type
    ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql') ? :jsonb : :json
  end

  def change
    create_table :telegram_bot_engine_subscriptions do |t|
      t.bigint :chat_id, null: false
      t.bigint :user_id
      t.string :username
      t.string :first_name
      t.boolean :active, default: true
      t.column :metadata, adapter_type, default: {}

      t.timestamps
    end

    add_index :telegram_bot_engine_subscriptions, :chat_id, unique: true
    add_index :telegram_bot_engine_subscriptions, :active
    add_index :telegram_bot_engine_subscriptions, :username
  end
end
