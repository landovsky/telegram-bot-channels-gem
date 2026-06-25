# frozen_string_literal: true

module TelegramBotEngine
  class Authorizer
    # Authorizes an inbound command username. `bot: nil` ⇒ global behavior, unchanged
    # (docs/0001 §3.5). When a bot is given in :database mode, both global (nil bot_id)
    # and that bot's own allow entries apply.
    def self.authorized?(username, bot: nil)
      return true if TelegramBotEngine.config.allowed_usernames.nil?

      allowed = resolve_allowed_usernames(bot)
      allowed.map(&:downcase).include?(username&.downcase)
    end

    def self.resolve_allowed_usernames(bot = nil)
      config = TelegramBotEngine.config.allowed_usernames

      case config
      when Array
        config
      when Proc
        config.call
      when :database
        scope = bot ? TelegramBotEngine::AllowedUser.for_bot(bot) : TelegramBotEngine::AllowedUser.all
        scope.pluck(:username)
      else
        []
      end
    end

    private_class_method :resolve_allowed_usernames
  end
end
