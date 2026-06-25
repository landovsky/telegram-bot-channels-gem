# frozen_string_literal: true

require "telegram/bot"
require "telegram_bot_engine/version"
require "telegram_bot_engine/configuration"
require "telegram_bot_engine/registry"
require "telegram_bot_engine/webhook_registrar"
require "telegram_bot_engine/dispatch"
require "telegram_bot_engine/authorizer"
require "telegram_bot_engine/subscriber_commands"
require "telegram_bot_engine/engine"

module TelegramBotEngine
  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = Configuration.new
    end

    # The Telegram::Bot::Client for a Bot record, resolved from the DB and cached by
    # bot id (token-rotation safe). See TelegramBotEngine::Registry / docs/0001 §3.2.
    def client_for(bot)
      Registry.client_for(bot)
    end

    # Broadcast to all active subscribers via background jobs, delivered through `bot`.
    # `bot:` omitted ⇒ the default bot ⇒ today's behavior, unchanged (docs/0001 §3.3).
    def broadcast(text, bot: nil, **options)
      bot ||= TelegramBotEngine::Bot.default
      subscriber_count = 0
      TelegramBotEngine::Subscription.active.for_bot(bot).find_each do |subscription|
        TelegramBotEngine::DeliveryJob.perform_later(
          bot.id,
          subscription.chat_id,
          text,
          options
        )
        subscriber_count += 1
      end

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "broadcast",
        bot_id: bot.id,
        details: { bot: bot.slug, subscriber_count: subscriber_count, text_preview: text.to_s[0, 100] }
      )
    end

    # Send to a specific chat via background job, delivered through `bot`.
    # `bot:` omitted ⇒ the default bot ⇒ today's behavior, unchanged (docs/0001 §3.3).
    def notify(chat_id:, text:, bot: nil, **options)
      bot ||= TelegramBotEngine::Bot.default
      TelegramBotEngine::DeliveryJob.perform_later(bot.id, chat_id, text, options)

      TelegramBotEngine::Event.log(
        event_type: "delivery", action: "notify",
        chat_id: chat_id, bot_id: bot.id,
        details: { bot: bot.slug, text_preview: text.to_s[0, 100] }
      )
    end
  end
end
