# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class AllowlistController < BaseController
      before_action :require_database_mode!

      def index
        @allowed_users = AllowedUser.order(:username)
      end

      def create
        AllowedUser.create!(allowed_user_params)
        redirect_to admin_allowlist_index_path, notice: "Username added to allowlist."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to admin_allowlist_index_path, alert: e.message
      end

      def destroy
        allowed_user = AllowedUser.find(params[:id])
        allowed_user.destroy!
        redirect_to admin_allowlist_index_path, notice: "Username removed from allowlist."
      end

      private

      def allowed_user_params
        params.require(:allowed_user).permit(:username, :note)
      end

      def require_database_mode!
        unless TelegramBotEngine.config.allowed_usernames == :database
          redirect_to admin_dashboard_path, alert: "Allowlist management is only available in database mode."
        end
      end
    end
  end
end
