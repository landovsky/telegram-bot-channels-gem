# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    # CRUD + token rotation + webhook status for bots-as-data (docs/0001 §3.8).
    class BotsController < BaseController
      before_action :set_bot, only: %i[edit update destroy rotate_token]

      def index
        @bots = Bot.order(:name)
      end

      def new
        @bot = Bot.new(active: true)
      end

      def create
        @bot = Bot.new(create_params)
        if @bot.save
          redirect_to admin_bots_path, notice: "Bot \"#{@bot.name}\" created."
        else
          flash.now[:alert] = @bot.errors.full_messages.to_sentence
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        # Token is never touched here — it is rotated through #rotate_token so a normal
        # edit can't blank it. See update_params.
        if @bot.update(update_params)
          redirect_to admin_bots_path, notice: "Bot \"#{@bot.name}\" updated."
        else
          flash.now[:alert] = @bot.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @bot.default?
          redirect_to admin_bots_path, alert: "Cannot delete the default bot. Promote another bot to default first."
        else
          @bot.destroy
          redirect_to admin_bots_path, notice: "Bot \"#{@bot.name}\" deleted."
        end
      end

      def rotate_token
        if params[:token].present?
          @bot.update!(token: params[:token])
          redirect_to admin_bots_path, notice: "Token rotated for \"#{@bot.name}\"."
        else
          redirect_to edit_admin_bot_path(@bot), alert: "Enter a new token to rotate."
        end
      end

      private

      def set_bot
        @bot = Bot.find(params[:id])
      end

      def create_params
        params.require(:bot).permit(:name, :slug, :purpose, :token, :active, :default)
      end

      def update_params
        params.require(:bot).permit(:name, :slug, :purpose, :active, :default)
      end
    end
  end
end
