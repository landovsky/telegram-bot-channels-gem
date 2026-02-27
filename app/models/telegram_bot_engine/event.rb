# frozen_string_literal: true

module TelegramBotEngine
  class Event < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_events"

    scope :recent, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(event_type: type) if type.present? }
    scope :by_action, ->(action) { where(action: action) if action.present? }
    scope :by_chat_id, ->(chat_id) { where(chat_id: chat_id) if chat_id.present? }
    scope :since, ->(time) { where("created_at >= ?", time) }

    validates :event_type, presence: true
    validates :action, presence: true

    def self.log(event_type:, action:, chat_id: nil, username: nil, details: {})
      return unless TelegramBotEngine.config.event_logging

      create!(
        event_type: event_type,
        action: action,
        chat_id: chat_id,
        username: username,
        details: details
      )

      purge_old_randomly!
    end

    def self.purge_old!
      where("created_at < ?", TelegramBotEngine.config.event_retention_days.days.ago).delete_all
    end

    def self.purge_old_randomly!
      purge_old! if rand(100).zero?
    end
  end
end
