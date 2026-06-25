# frozen_string_literal: true

class CreateTelegramBotEngineBots < ActiveRecord::Migration[7.0]
  def change
    create_table :telegram_bot_engine_bots do |t|
      t.string  :name,           null: false
      t.string  :slug,           null: false
      t.string  :purpose
      t.string  :token,          null: false                 # encrypted at rest once keys are provisioned (docs/0001 §6)
      t.string  :webhook_secret, null: false                 # per-bot inbound secret path segment
      t.boolean :active,         null: false, default: true
      t.boolean :default,        null: false, default: false # exactly one row true (enforced in the model)

      t.timestamps
    end

    add_index :telegram_bot_engine_bots, :slug, unique: true
    add_index :telegram_bot_engine_bots, :webhook_secret, unique: true
    add_index :telegram_bot_engine_bots, :active
  end
end
