# frozen_string_literal: true

module TelegramBotEngine
  class DeliveryJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(chat_id, text, options = {})
      Telegram.bot.send_message(
        chat_id: chat_id,
        text: text,
        **options.symbolize_keys
      )

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "delivered",
        chat_id: chat_id,
        details: { text_preview: text.to_s[0, 100] }
      )
    rescue Telegram::Bot::Forbidden
      # User blocked the bot - deactivate subscription
      TelegramBotEngine::Subscription.where(chat_id: chat_id).update_all(active: false)
      Rails.logger.info("[TelegramBotEngine] Deactivated subscription for blocked chat: #{chat_id}")

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "blocked",
        chat_id: chat_id,
        details: { text_preview: text.to_s[0, 100] }
      )
    end
  end
end
