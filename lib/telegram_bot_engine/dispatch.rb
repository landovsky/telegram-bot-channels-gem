# frozen_string_literal: true

require "action_dispatch"
require "active_support/security_utils"

module TelegramBotEngine
  # The single inbound webhook endpoint for ALL bots (docs/0001 §3.7). The host app mounts
  # this once: `mount TelegramBotEngine::Dispatch, at: config.webhook_mount_path`. For
  # `POST <mount>/:webhook_secret` it resolves the Bot by its secret path segment, validates
  # the X-Telegram-Bot-Api-Secret-Token header (telegram-bot 0.16 does NOT — docs/0001 §9),
  # then hands off to the host's UpdatesController via `dispatch(bot.client, update, request)`.
  class Dispatch
    SECRET_TOKEN_HEADER = "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"
    # The resolved Bot record is exposed to the controller here so SubscriberCommands can
    # scope inbound /start·/stop to the bot the update arrived for.
    ENV_BOT_KEY = "telegram_bot_engine.bot"

    def self.call(env)
      new.call(env)
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return respond(405, "method not allowed") unless request.post?

      bot = resolve_bot(request)
      return respond(404, "unknown bot") unless bot
      return respond(403, "invalid secret token") unless valid_secret_token?(request, bot)

      controller = dispatch_controller
      return respond(503, "dispatch_controller not configured") unless controller

      begin
        update = request.request_parameters
      rescue ActionDispatch::Http::Parameters::ParseError
        return respond(400, "bad request")
      end

      request.set_header(ENV_BOT_KEY, bot)
      controller.dispatch(bot.client, update, request)
      respond(200, "")
    end

    private

    def resolve_bot(request)
      # Route on the NON-secret webhook_id path segment; the secret_token is validated from the
      # header only (docs/0001 §3.7) so the credential never reaches request/SQL logs.
      webhook_id = request.path_info.to_s.split("/").reject(&:empty?).last
      return nil if webhook_id.blank?

      TelegramBotEngine::Bot.active.find_by(webhook_id: webhook_id)
    end

    def valid_secret_token?(request, bot)
      provided = request.get_header(SECRET_TOKEN_HEADER).to_s
      return false if provided.empty?

      ActiveSupport::SecurityUtils.secure_compare(provided, bot.webhook_secret.to_s)
    end

    def dispatch_controller
      target = TelegramBotEngine.config.dispatch_controller
      return nil if target.blank?

      target.respond_to?(:dispatch) ? target : target.to_s.constantize
    end

    def respond(status, body)
      [status, { "Content-Type" => "text/plain; charset=utf-8" }, [body]]
    end
  end
end
