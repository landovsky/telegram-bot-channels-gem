# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class EventsController < BaseController
      PER_PAGE = 50

      def index
        unless Event.table_exists?
          respond_to do |format|
            format.html do
              @events = []
              @total_count = 0
              @page = 1
              @total_pages = 0
              flash.now[:alert] = "Events table not found. Run: rails telegram_bot_engine:install:migrations && rails db:migrate"
            end
            format.json { render json: { error: "Events table not found" }, status: :service_unavailable }
          end
          return
        end

        @events = Event.recent
        @events = @events.by_type(params[:type]) if params[:type].present?
        @events = @events.by_action(params[:action_name]) if params[:action_name].present?
        @events = @events.by_chat_id(params[:chat_id]) if params[:chat_id].present?

        @total_count = @events.count
        @page = [params[:page].to_i, 1].max
        @events = @events.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
        @total_pages = (@total_count.to_f / PER_PAGE).ceil

        respond_to do |format|
          format.html
          format.json do
            render json: {
              events: @events.map { |e|
                {
                  id: e.id,
                  event_type: e.event_type,
                  action: e.action,
                  chat_id: e.chat_id,
                  username: e.username,
                  details: e.details,
                  created_at: e.created_at.iso8601
                }
              },
              meta: {
                total_count: @total_count,
                page: @page,
                total_pages: @total_pages,
                per_page: PER_PAGE
              }
            }
          end
        end
      end
    end
  end
end
