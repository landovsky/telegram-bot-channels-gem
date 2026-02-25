# frozen_string_literal: true

class CreateTelegramBotEngineAllowedUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :telegram_bot_engine_allowed_users do |t|
      t.string :username, null: false
      t.string :note

      t.timestamps
    end

    add_index :telegram_bot_engine_allowed_users, :username, unique: true
  end
end
