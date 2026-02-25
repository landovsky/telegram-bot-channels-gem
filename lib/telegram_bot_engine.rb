# frozen_string_literal: true

require "telegram/bot"
require "telegram_bot_engine/version"
require "telegram_bot_engine/configuration"
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

    # Broadcast to all active subscribers via background jobs
    def broadcast(text, **options)
      TelegramBotEngine::Subscription.active.find_each do |subscription|
        TelegramBotEngine::DeliveryJob.perform_later(
          subscription.chat_id,
          text,
          options
        )
      end
    end

    # Send to a specific chat via background job
    def notify(chat_id:, text:, **options)
      TelegramBotEngine::DeliveryJob.perform_later(chat_id, text, options)
    end
  end
end
