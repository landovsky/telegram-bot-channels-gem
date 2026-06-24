# frozen_string_literal: true

module TelegramBotEngine
  class DeliveryJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    # Delivers through the chosen bot's own client (resolved via the registry),
    # not the process-global Telegram.bot (docs/0001 §3.3). `bot_id` is resolved
    # to a Bot record; a missing/blank id falls back to the default bot so an
    # in-flight job enqueued before a rollback still delivers.
    def perform(bot_id, chat_id, text, options = {})
      bot = TelegramBotEngine::Bot.find_by(id: bot_id) || TelegramBotEngine::Bot.default

      TelegramBotEngine.client_for(bot).send_message(
        chat_id: chat_id,
        text: text,
        **options.symbolize_keys
      )

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "delivered",
        chat_id: chat_id, bot_id: bot.id,
        details: { bot: bot.slug, text_preview: text.to_s[0, 100] }
      )
    rescue Telegram::Bot::Forbidden
      # User blocked this bot - deactivate only *this bot's* subscription for the chat,
      # not the chat's subscriptions to other bots (docs/0001 §3.4).
      TelegramBotEngine::Subscription.for_bot(bot).where(chat_id: chat_id).update_all(active: false)
      Rails.logger.info("[TelegramBotEngine] Deactivated subscription for blocked chat: #{chat_id}")

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "blocked",
        chat_id: chat_id, bot_id: bot&.id,
        details: { bot: bot&.slug, text_preview: text.to_s[0, 100] }
      )
    end
  end
end
