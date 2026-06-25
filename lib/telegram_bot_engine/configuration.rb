# frozen_string_literal: true

module TelegramBotEngine
  class Configuration
    attr_accessor :allowed_usernames, :admin_enabled, :unauthorized_message, :welcome_message,
                  :event_logging, :event_retention_days,
                  # Phase 3 — webhook registrar (§3.6) + inbound dispatcher (§3.7)
                  :webhook_base_url, :webhook_mount_path, :dispatch_controller, :auto_register_webhooks

    def initialize
      @allowed_usernames = nil
      @admin_enabled = true
      @unauthorized_message = "Sorry, you're not authorized to use this bot."
      @welcome_message = "Welcome %{username}! Available commands:\n%{commands}"
      @event_logging = true
      @event_retention_days = 30

      @webhook_base_url = nil               # host public https base, e.g. "https://app.example.com"
      @webhook_mount_path = "/telegram/bot" # MUST match `mount TelegramBotEngine::Dispatch, at:`
      @dispatch_controller = nil            # host UpdatesController (String/class) incl. SubscriberCommands
      @auto_register_webhooks = true        # (un)register webhooks on Bot save/destroy when base_url present
    end
  end
end
