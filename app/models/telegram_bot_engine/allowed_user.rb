# frozen_string_literal: true

module TelegramBotEngine
  class AllowedUser < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_allowed_users"

    belongs_to :bot, class_name: "TelegramBotEngine::Bot", optional: true

    # Entries authorizing inbound commands for a bot: a nil bot_id is a GLOBAL allow
    # that applies to every bot, layered with that bot's own entries (docs/0001 §3.5).
    scope :for_bot, ->(bot) { bot ? where(bot_id: [nil, bot.id]) : all }

    validates :username, presence: true, uniqueness: { scope: :bot_id }
  end
end
