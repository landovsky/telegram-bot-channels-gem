# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class AllowlistController < BaseController
      before_action :require_database_mode!

      def index
        @bots = Bot.order(:name)
        @allowed_users = AllowedUser.includes(:bot).order(:username)
        @allowed_users = @allowed_users.where(bot_id: params[:bot_id]) if params[:bot_id].present?
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
        # bot_id blank ⇒ a global allow entry that applies to every bot (docs/0001 §3.5).
        params.require(:allowed_user).permit(:username, :note, :bot_id)
      end

      def require_database_mode!
        unless TelegramBotEngine.config.allowed_usernames == :database
          redirect_to admin_dashboard_path, alert: "Allowlist management is only available in database mode."
        end
      end
    end
  end
end
