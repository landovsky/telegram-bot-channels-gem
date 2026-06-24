# frozen_string_literal: true

module TelegramBotEngine
  # Registers/removes a bot's Telegram webhook (docs/0001 §3.6). The webhook URL embeds the
  # bot's per-bot `webhook_secret` path segment, and `secret_token` is set to the same secret
  # so the inbound dispatcher can authenticate Telegram via the X-Telegram-Bot-Api-Secret-Token
  # header. setWebhook is idempotent (overwrites), so re-registering is always safe.
  module WebhookRegistrar
    class << self
      def register(bot, base_url: nil)
        base_url ||= TelegramBotEngine.config.webhook_base_url
        return false if base_url.blank?

        TelegramBotEngine.client_for(bot).set_webhook(
          url: webhook_url(bot, base_url),
          secret_token: bot.webhook_secret
        )
        true
      end

      def remove(bot)
        TelegramBotEngine.client_for(bot).delete_webhook
        true
      end

      def webhook_url(bot, base_url)
        # The URL path carries the NON-secret webhook_id; the secret stays in secret_token only.
        "#{base_url.to_s.chomp('/')}#{TelegramBotEngine.config.webhook_mount_path}/#{bot.webhook_id}"
      end
    end
  end
end
