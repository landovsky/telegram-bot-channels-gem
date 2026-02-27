# frozen_string_literal: true

module TelegramBotEngine
  class Configuration
    attr_accessor :allowed_usernames, :admin_enabled, :unauthorized_message, :welcome_message,
                  :event_logging, :event_retention_days

    def initialize
      @allowed_usernames = nil
      @admin_enabled = true
      @unauthorized_message = "Sorry, you're not authorized to use this bot."
      @welcome_message = "Welcome %{username}! Available commands:\n%{commands}"
      @event_logging = true
      @event_retention_days = 30
    end
  end
end
