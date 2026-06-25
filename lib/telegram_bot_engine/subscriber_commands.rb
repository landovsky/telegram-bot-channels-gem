# frozen_string_literal: true

module TelegramBotEngine
  module SubscriberCommands
    extend ActiveSupport::Concern

    included do
      skip_forgery_protection if respond_to?(:skip_forgery_protection)
      before_action :authorize_user!
    end

    # /start - create subscription if authorized
    def start!(*)
      subscription = TelegramBotEngine::Subscription.find_or_initialize_by(
        chat_id: chat["id"], bot_id: current_bot&.id
      )
      subscription.assign_attributes(
        user_id: from["id"],
        username: from["username"],
        first_name: from["first_name"],
        active: true
      )
      subscription.save!

      TelegramBotEngine::Event.log(
        event_type: "command", action: "start",
        chat_id: chat["id"], username: from["username"], bot_id: current_bot&.id
      )

      welcome = TelegramBotEngine.config.welcome_message % {
        username: from["first_name"] || from["username"],
        commands: available_commands_text
      }
      respond_with :message, text: welcome
    end

    # /stop - deactivate subscription
    def stop!(*)
      subscription = TelegramBotEngine::Subscription.find_by(chat_id: chat["id"], bot_id: current_bot&.id)
      subscription&.update(active: false)

      TelegramBotEngine::Event.log(
        event_type: "command", action: "stop",
        chat_id: chat["id"], username: from["username"], bot_id: current_bot&.id
      )

      respond_with :message, text: "You've been unsubscribed. Send /start to resubscribe."
    end

    # /help - list all available commands
    def help!(*)
      TelegramBotEngine::Event.log(
        event_type: "command", action: "help",
        chat_id: chat["id"], username: from["username"], bot_id: current_bot&.id
      )

      respond_with :message, text: "📋 *Available Commands*\n\n#{available_commands_text}", parse_mode: "Markdown"
    end

    private

    def authorize_user!
      return if TelegramBotEngine::Authorizer.authorized?(from["username"], bot: current_bot)

      TelegramBotEngine::Event.log(
        event_type: "auth_failure", action: "unauthorized",
        chat_id: chat["id"], username: from["username"], bot_id: current_bot&.id
      )

      respond_with :message, text: TelegramBotEngine.config.unauthorized_message
      throw :abort
    end

    # The Bot this inbound update arrived for, set by TelegramBotEngine::Dispatch in the
    # request env (docs/0001 §3.7). nil when there is no inbound request context (e.g. the
    # poller, or a host controller without webhook_request) → default/global behavior, unchanged.
    def current_bot
      return unless respond_to?(:webhook_request)

      request = webhook_request
      request && request.env["telegram_bot_engine.bot"]
    end

    # Auto-generates command list from public methods ending with !
    def available_commands_text
      commands = self.class.public_instance_methods(false)
                     .select { |m| m.to_s.end_with?("!") }
                     .map { |m| "/#{m.to_s.delete_suffix('!')}" }

      all_commands = ["/start", "/stop", "/help"] | commands
      all_commands.join("\n")
    end
  end
end
