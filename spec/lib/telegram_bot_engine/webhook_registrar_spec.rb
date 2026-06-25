# frozen_string_literal: true

RSpec.describe TelegramBotEngine::WebhookRegistrar do
  around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

  # Test the registrar in isolation — disable the Bot-save auto-hook so creating a bot
  # doesn't itself fire setWebhook.
  before { TelegramBotEngine.configure { |c| c.auto_register_webhooks = false } }

  describe ".register" do
    it "puts the NON-secret webhook_id in the URL and the secret ONLY in secret_token" do
      bot = create(:bot, :default, webhook_id: "rt3", webhook_secret: "s3cr3t")

      described_class.register(bot, base_url: "https://example.com")

      req = TelegramBotEngine.client_for(bot).requests[:setWebhook].last
      expect(req[:url]).to eq("https://example.com/telegram/bot/rt3")
      expect(req[:url]).not_to include("s3cr3t") # the secret must never appear in the URL/logs
      expect(req[:secret_token]).to eq("s3cr3t")
    end

    it "falls back to config.webhook_base_url" do
      TelegramBotEngine.configure { |c| c.webhook_base_url = "https://configured.example" }
      bot = create(:bot, :default, webhook_id: "abc")

      described_class.register(bot)

      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook].last[:url])
        .to eq("https://configured.example/telegram/bot/abc")
    end

    it "honors a custom webhook_mount_path" do
      TelegramBotEngine.configure { |c| c.webhook_mount_path = "/tg/in" }
      bot = create(:bot, :default, webhook_id: "abc")

      described_class.register(bot, base_url: "https://example.com")

      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook].last[:url])
        .to eq("https://example.com/tg/in/abc")
    end

    it "strips a trailing slash from base_url" do
      bot = create(:bot, :default, webhook_id: "x")

      described_class.register(bot, base_url: "https://example.com/")

      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook].last[:url])
        .to eq("https://example.com/telegram/bot/x")
    end

    it "is a no-op when no base_url is available anywhere" do
      bot = create(:bot, :default)

      expect(described_class.register(bot)).to be false
      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook]).to be_empty
    end
  end

  describe ".remove" do
    it "deletes the webhook on the bot's own client" do
      bot = create(:bot, :default)

      described_class.remove(bot)

      expect(TelegramBotEngine.client_for(bot).requests[:deleteWebhook]).not_to be_empty
    end
  end
end
