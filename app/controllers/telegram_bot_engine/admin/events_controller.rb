# frozen_string_literal: true

module TelegramBotEngine
  module Admin
    class EventsController < BaseController
      PER_PAGE = 50

      def index
        @events = Event.recent
        @events = @events.by_type(params[:type]) if params[:type].present?
        @events = @events.by_action(params[:action_name]) if params[:action_name].present?
        @events = @events.by_chat_id(params[:chat_id]) if params[:chat_id].present?

        @total_count = @events.count
        @page = [params[:page].to_i, 1].max
        @events = @events.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
        @total_pages = (@total_count.to_f / PER_PAGE).ceil
      end
    end
  end
end
