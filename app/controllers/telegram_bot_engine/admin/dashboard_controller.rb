# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class DashboardController < BaseController
      def show
        @bots = Bot.order(:name)
        @bot_active_counts = @bots.index_with { |bot| Subscription.active.for_bot(bot).count }

        @total_subscriptions = Subscription.count
        @active_subscriptions = Subscription.active.count
        @inactive_subscriptions = @total_subscriptions - @active_subscriptions

        # Legacy single-bot fallback (docs/0001 §3.8): only shown until bots-as-data
        # rows exist, so pre-multi-bot installs still render their bot identity.
        @bot_username = bot_username
      end

      private

      def bot_username
        Telegram.bot.username
      rescue StandardError
        nil
      end
    end
  end
end
