# frozen_string_literal: true

module TelegramBotEngine
  # Resolves and caches a Telegram::Bot::Client per Bot record, keyed by bot id
  # (docs/0001 §2 cap 2, §3.2). This fills telegram-bot's gap: `Telegram.bots` is
  # boot-memoized (`@bots ||=`) and not built for runtime hot-add or token rotation.
  # We resolve a fresh `Telegram::Bot::Client.new(token)` per bot_id rather than
  # leaning on `Telegram.reset_bots`, which is unsafe under concurrency (docs/0001 §9).
  module Registry
    @mutex = Mutex.new
    @clients = {}

    class << self
      # The client for this bot, built once and cached by bot id.
      def client_for(bot)
        @mutex.synchronize do
          @clients[bot.id] ||= build_client(bot)
        end
      end

      # Drop a bot's cached client so the next resolve rebuilds it. Called from
      # Bot#after_save / #after_destroy so token rotation can never serve a stale client.
      def invalidate(bot)
        @mutex.synchronize { @clients.delete(bot.id) }
      end

      # Clear the whole cache (test isolation; also safe to call on reload).
      def reset!
        @mutex.synchronize { @clients = {} }
      end

      private

      def build_client(bot)
        Telegram::Bot::Client.new(bot.token, bot.slug)
      end
    end
  end
end
