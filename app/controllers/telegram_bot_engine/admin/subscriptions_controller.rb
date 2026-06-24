# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class SubscriptionsController < BaseController
      def index
        @bots = Bot.order(:name)
        @subscriptions = Subscription.includes(:bot).order(created_at: :desc)
        @subscriptions = @subscriptions.where(bot_id: params[:bot_id]) if params[:bot_id].present?
      end

      def update
        subscription = Subscription.find(params[:id])
        subscription.update!(active: !subscription.active)
        redirect_to admin_subscriptions_path, notice: "Subscription #{subscription.active ? 'activated' : 'deactivated'}."
      end

      def destroy
        subscription = Subscription.find(params[:id])
        subscription.destroy!
        redirect_to admin_subscriptions_path, notice: "Subscription deleted."
      end
    end
  end
end
