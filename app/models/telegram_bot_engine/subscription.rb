# frozen_string_literal: true

module TelegramBotEngine
  class Subscription < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_subscriptions"

    belongs_to :bot, class_name: "TelegramBotEngine::Bot", optional: true

    scope :active, -> { where(active: true) }

    # The audience for a bot (docs/0001 §3.4). A subscription with a nil bot_id is
    # treated as belonging to the default bot, so pre-multi-bot subscribers keep
    # receiving default broadcasts without a data migration (§4 back-compat).
    scope :for_bot, lambda { |bot|
      if bot&.default?
        where(bot_id: [bot.id, nil])
      else
        where(bot_id: bot&.id)
      end
    }

    validates :chat_id, presence: true, uniqueness: { scope: :bot_id }
  end
end
