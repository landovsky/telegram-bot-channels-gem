# frozen_string_literal: true

RSpec.describe TelegramBotEngine do
  include ActiveJob::TestHelper

  describe ".broadcast" do
    let!(:default_bot) { create(:bot, :default) }

    it "enqueues a delivery job for each active subscription" do
      create(:subscription, chat_id: 111, active: true)
      create(:subscription, chat_id: 222, active: true)
      create(:subscription, chat_id: 333, active: false)

      expect {
        described_class.broadcast("Test message")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob).exactly(2).times
    end

    context "back-compat — a no-`bot:` broadcast must target the default bot unchanged" do
      it "tags each enqueued job with the default bot id" do
        create(:subscription, chat_id: 111, active: true)

        expect {
          described_class.broadcast("Hello!", parse_mode: "Markdown")
        }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
          .with(default_bot.id, 111, "Hello!", { parse_mode: "Markdown" })
      end
    end

    context "when a bot is chosen explicitly" do
      it "tags jobs with that bot id and scopes to that bot's own subscribers" do
        assistant = create(:bot, slug: "assistant")
        create(:subscription, chat_id: 111, active: true, bot: assistant)
        create(:subscription, chat_id: 999, active: true) # default/legacy audience — must be excluded

        expect {
          described_class.broadcast("Hi", bot: assistant)
        }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
          .with(assistant.id, 111, "Hi", {})
        expect(TelegramBotEngine::DeliveryJob).not_to have_been_enqueued.with(assistant.id, 999, "Hi", {})
      end
    end

    it "does nothing when no active subscriptions" do
      create(:subscription, chat_id: 111, active: false)

      expect {
        described_class.broadcast("Hello!")
      }.not_to have_enqueued_job(TelegramBotEngine::DeliveryJob)
    end
  end

  describe ".notify" do
    let!(:default_bot) { create(:bot, :default) }

    context "back-compat — a no-`bot:` notify targets the default bot" do
      it "enqueues a delivery job tagged with the default bot id" do
        expect {
          described_class.notify(chat_id: 12345, text: "Direct message")
        }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
          .with(default_bot.id, 12345, "Direct message", {})
      end
    end

    it "passes additional options" do
      expect {
        described_class.notify(chat_id: 12345, text: "Hello", parse_mode: "HTML")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
        .with(default_bot.id, 12345, "Hello", { parse_mode: "HTML" })
    end

    it "routes to an explicitly chosen bot" do
      assistant = create(:bot, slug: "assistant")

      expect {
        described_class.notify(chat_id: 12345, text: "Hello", bot: assistant)
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
        .with(assistant.id, 12345, "Hello", {})
    end
  end
end
