# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class DashboardController < BaseController
      def show
        @total_subscriptions = Subscription.count
        @active_subscriptions = Subscription.active.count
        @inactive_subscriptions = @total_subscriptions - @active_subscriptions
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
