# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Bot do
  describe "validations" do
    it "requires a name, slug, and token" do
      bot = described_class.new
      bot.valid?
      expect(bot.errors.attribute_names).to include(:name, :slug, :token)
    end

    it "enforces a unique slug so a bot has one stable handle" do
      create(:bot, slug: "assistant")
      dup = build(:bot, slug: "assistant")
      expect(dup).not_to be_valid
      expect(dup.errors[:slug]).to be_present
    end

    it "auto-generates a webhook_secret when none is supplied" do
      bot = described_class.create!(name: "X", slug: "x", token: "t")
      expect(bot.webhook_secret).to be_present
    end

    it "auto-generates a distinct, non-secret webhook_id (routing id) decoupled from the secret" do
      bot = described_class.create!(name: "X", slug: "x", token: "t")
      expect(bot.webhook_id).to be_present
      expect(bot.webhook_id).not_to eq(bot.webhook_secret)
    end

    it "enforces a unique webhook_secret (it is an inbound routing key)" do
      create(:bot, webhook_secret: "shared")
      dup = build(:bot, webhook_secret: "shared")
      expect(dup).not_to be_valid
      expect(dup.errors[:webhook_secret]).to be_present
    end
  end

  describe ".default" do
    it "returns the bot flagged default" do
      default_bot = create(:bot, :default)
      create(:bot, slug: "assistant")
      expect(described_class.default).to eq(default_bot)
    end

    context "exactly one row true — promoting a new default must demote the old one" do
      it "leaves a single default after a second bot is promoted" do
        first = create(:bot, :default)
        second = create(:bot, slug: "assistant")
        second.update!(default: true)

        expect(first.reload.default).to be false
        expect(described_class.where(default: true).count).to eq(1)
        expect(described_class.default).to eq(second)
      end
    end

    context "exactly one row true — the last default must never be cleared" do
      it "refuses to unset default on the only default bot (the no-bot: back-compat anchor must survive)" do
        bot = create(:bot, :default)

        expect(bot.update(default: false)).to be false
        expect(bot.errors[:default]).to be_present
        expect(bot.reload.default).to be true
        expect(described_class.default).to eq(bot)
      end

      it "does not trip the guard when a non-default bot is edited" do
        create(:bot, :default)
        assistant = create(:bot, slug: "assistant")

        expect(assistant.update(name: "Renamed")).to be true
      end
    end
  end

  describe ".resolve" do
    it "looks a bot up by its slug handle" do
      bot = create(:bot, slug: "assistant")
      expect(described_class.resolve("assistant")).to eq(bot)
    end

    it "raises for an unknown slug" do
      expect { described_class.resolve("nope") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".ensure_default!" do
    it "is idempotent when a default already exists" do
      existing = create(:bot, :default)
      expect { described_class.ensure_default! }.not_to change(described_class, :count)
      expect(described_class.ensure_default!).to eq(existing)
    end

    it "seeds a default from the host's existing single-bot config so first boot keeps working" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_BOT_TOKEN").and_return(nil)
      allow(Telegram).to receive(:bots_config)
        .and_return({ default: { "token" => "seed-token", "username" => "seeded_bot" } })

      bot = described_class.ensure_default!

      expect(bot.slug).to eq("default")
      expect(bot.default).to be true
      expect(bot.token).to eq("seed-token")
      expect(bot.name).to eq("seeded_bot")
    end

    it "prefers ENV['TELEGRAM_BOT_TOKEN'] as the seed source" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("TELEGRAM_BOT_TOKEN").and_return("env-token")

      expect(described_class.ensure_default!.token).to eq("env-token")
    end
  end

  describe "#client" do
    around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

    it "returns the registry-resolved client and memoizes it across calls" do
      bot = create(:bot, :default)
      expect(bot.client).to be(bot.client)
      expect(bot.client).to be(TelegramBotEngine.client_for(bot))
    end
  end

  describe "webhook auto-(un)registration on save/destroy (§3.6)" do
    around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

    context "when a base_url is configured" do
      before { TelegramBotEngine.configure { |c| c.webhook_base_url = "https://example.com" } }

      it "registers the webhook (URL carries the non-secret webhook_id) when an active bot is saved" do
        bot = create(:bot, :default, webhook_id: "wh")

        expect(TelegramBotEngine.client_for(bot).requests[:setWebhook].last[:url])
          .to eq("https://example.com/telegram/bot/wh")
      end

      it "does NOT auto-register on the implicit Bot.default lazy seed (keeps the broadcast path I/O-free)" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("TELEGRAM_BOT_TOKEN").and_return("seed-token")

        bot = TelegramBotEngine::Bot.default # lazy-seeds the default from ENV

        expect(TelegramBotEngine.client_for(bot).requests[:setWebhook]).to be_empty
      end

      it "removes the webhook when a bot is destroyed" do
        assistant = create(:bot, slug: "assistant")

        assistant.destroy

        # after_destroy invalidates the cached client first, so remove_webhook builds a fresh
        # one carrying only the deleteWebhook call.
        expect(TelegramBotEngine.client_for(assistant).requests[:deleteWebhook]).not_to be_empty
      end

      it "logs (never raises) when the Telegram call fails, so the admin save still succeeds" do
        allow(TelegramBotEngine::WebhookRegistrar).to receive(:register).and_raise(StandardError, "boom")
        bot = build(:bot, :default, webhook_secret: "wh")

        expect { bot.save! }.not_to raise_error
        expect(TelegramBotEngine::Event.where(event_type: "webhook", action: "register_failed")).to exist
      end
    end

    it "makes no network call when no base_url is configured (gem suite + unconfigured hosts stay offline)" do
      bot = create(:bot, :default)
      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook]).to be_empty
    end

    it "does not auto-register when auto_register_webhooks is false" do
      TelegramBotEngine.configure do |c|
        c.webhook_base_url = "https://example.com"
        c.auto_register_webhooks = false
      end
      bot = create(:bot, :default)
      expect(TelegramBotEngine.client_for(bot).requests[:setWebhook]).to be_empty
    end
  end
end
