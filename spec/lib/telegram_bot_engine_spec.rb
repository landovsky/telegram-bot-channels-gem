# frozen_string_literal: true

RSpec.describe TelegramBotEngine do
  include ActiveJob::TestHelper

  describe ".broadcast" do
    it "enqueues a delivery job for each active subscription" do
      create(:subscription, chat_id: 111, active: true)
      create(:subscription, chat_id: 222, active: true)
      create(:subscription, chat_id: 333, active: false)

      expect {
        described_class.broadcast("Test message")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob).exactly(2).times
    end

    it "enqueues jobs with correct arguments" do
      create(:subscription, chat_id: 111, active: true)

      expect {
        described_class.broadcast("Hello!", parse_mode: "Markdown")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
        .with(111, "Hello!", { parse_mode: "Markdown" })
    end

    it "does nothing when no active subscriptions" do
      create(:subscription, chat_id: 111, active: false)

      expect {
        described_class.broadcast("Hello!")
      }.not_to have_enqueued_job(TelegramBotEngine::DeliveryJob)
    end
  end

  describe ".notify" do
    it "enqueues a delivery job for a specific chat" do
      expect {
        described_class.notify(chat_id: 12345, text: "Direct message")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
        .with(12345, "Direct message", {})
    end

    it "passes additional options" do
      expect {
        described_class.notify(chat_id: 12345, text: "Hello", parse_mode: "HTML")
      }.to have_enqueued_job(TelegramBotEngine::DeliveryJob)
        .with(12345, "Hello", { parse_mode: "HTML" })
    end
  end
end
