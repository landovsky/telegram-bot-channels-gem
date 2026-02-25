# frozen_string_literal: true

module TelegramBotEngine
  class Configuration
    attr_accessor :allowed_usernames, :admin_enabled, :unauthorized_message, :welcome_message

    def initialize
      @allowed_usernames = nil
      @admin_enabled = true
      @unauthorized_message = "Sorry, you're not authorized to use this bot."
      @welcome_message = "Welcome %{username}! Available commands:\n%{commands}"
    end
  end
end
