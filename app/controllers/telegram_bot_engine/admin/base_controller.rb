# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class BaseController < ActionController::Base
      layout "telegram_bot_engine/admin/layouts/application"

      before_action :check_admin_enabled!

      private

      def check_admin_enabled!
        raise ActionController::RoutingError, "Not Found" unless TelegramBotEngine.config.admin_enabled
      end
    end
  end
end
