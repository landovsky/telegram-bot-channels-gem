# frozen_string_literal: true

module TelegramBotEngine
  class AllowedUser < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_allowed_users"

    validates :username, presence: true, uniqueness: true
  end
end
