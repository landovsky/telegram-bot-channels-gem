# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class SubscriptionsController < BaseController
      def index
        @subscriptions = Subscription.order(created_at: :desc)
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
