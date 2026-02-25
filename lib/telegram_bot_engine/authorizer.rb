# frozen_string_literal: true

module TelegramBotEngine
  class Authorizer
    def self.authorized?(username)
      return true if TelegramBotEngine.config.allowed_usernames.nil?

      allowed = resolve_allowed_usernames
      allowed.map(&:downcase).include?(username&.downcase)
    end

    private

    def self.resolve_allowed_usernames
      config = TelegramBotEngine.config.allowed_usernames

      case config
      when Array
        config
      when Proc
        config.call
      when :database
        TelegramBotEngine::AllowedUser.pluck(:username)
      else
        []
      end
    end
  end
end
