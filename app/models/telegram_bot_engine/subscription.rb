# frozen_string_literal: true

module TelegramBotEngine
  class Subscription < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_subscriptions"

    scope :active, -> { where(active: true) }

    validates :chat_id, presence: true, uniqueness: true
  end
end
