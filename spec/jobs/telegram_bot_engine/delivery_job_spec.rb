# frozen_string_literal: true

RSpec.describe TelegramBotEngine::DeliveryJob do
  include ActiveJob::TestHelper

  let(:bot_client) { instance_double("Telegram::Bot::Client") }

  before do
    allow(Telegram).to receive(:bot).and_return(bot_client)
  end

  describe "#perform" do
    it "sends a message via Telegram bot client" do
      expect(bot_client).to receive(:send_message).with(
        chat_id: 12345,
        text: "Hello!"
      )

      described_class.new.perform(12345, "Hello!")
    end

    it "passes additional options" do
      expect(bot_client).to receive(:send_message).with(
        chat_id: 12345,
        text: "Hello!",
        parse_mode: "Markdown"
      )

      described_class.new.perform(12345, "Hello!", { "parse_mode" => "Markdown" })
    end

    it "symbolizes option keys" do
      expect(bot_client).to receive(:send_message).with(
        chat_id: 12345,
        text: "Test",
        parse_mode: "HTML"
      )

      described_class.new.perform(12345, "Test", { "parse_mode" => "HTML" })
    end

    it "logs a delivered event" do
      allow(bot_client).to receive(:send_message)

      described_class.new.perform(12345, "Hello!")

      event = TelegramBotEngine::Event.last
      expect(event.event_type).to eq("delivery")
      expect(event.action).to eq("delivered")
      expect(event.chat_id).to eq(12345)
    end

    context "when user blocked the bot" do
      before do
        allow(bot_client).to receive(:send_message).and_raise(Telegram::Bot::Forbidden, "bot was blocked")
      end

      it "deactivates the subscription" do
        sub = create(:subscription, chat_id: 12345, active: true)

        described_class.new.perform(12345, "Hello!")

        sub.reload
        expect(sub.active).to be false
      end

      it "handles missing subscription gracefully" do
        expect { described_class.new.perform(99999, "Hello!") }.not_to raise_error
      end

      it "logs a blocked event" do
        create(:subscription, chat_id: 12345, active: true)
        described_class.new.perform(12345, "Hello!")

        event = TelegramBotEngine::Event.last
        expect(event.event_type).to eq("delivery")
        expect(event.action).to eq("blocked")
        expect(event.chat_id).to eq(12345)
      end
    end
  end

  describe "job configuration" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "enqueues the job" do
      expect {
        described_class.perform_later(12345, "Hello!", {})
      }.to have_enqueued_job(described_class)
    end
  end
end
