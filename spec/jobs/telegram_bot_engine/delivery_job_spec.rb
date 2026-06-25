# frozen_string_literal: true

RSpec.describe TelegramBotEngine::DeliveryJob do
  include ActiveJob::TestHelper

  # Use telegram-bot's real ClientStub seam (not a hand-rolled double) so the job
  # exercises the same resolution path production does: a per-bot client from the
  # registry, never the process-global Telegram.bot.
  around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

  let(:bot) { create(:bot, :default) }

  describe "#perform" do
    it "delivers through the bot's own client rather than the global Telegram.bot" do
      described_class.new.perform(bot.id, 12345, "Hello!")

      expect(TelegramBotEngine.client_for(bot).requests[:sendMessage])
        .to include(hash_including(chat_id: 12345, text: "Hello!"))
    end

    it "passes and symbolizes additional options" do
      described_class.new.perform(bot.id, 12345, "Test", { "parse_mode" => "HTML" })

      expect(TelegramBotEngine.client_for(bot).requests[:sendMessage])
        .to include(hash_including(chat_id: 12345, text: "Test", parse_mode: "HTML"))
    end

    it "falls back to the default bot when bot_id is missing (in-flight job across a rollback)" do
      bot # ensure a default exists
      described_class.new.perform(nil, 12345, "Hello!")

      expect(TelegramBotEngine.client_for(TelegramBotEngine::Bot.default).requests[:sendMessage])
        .to include(hash_including(chat_id: 12345, text: "Hello!"))
    end

    it "logs a delivered event" do
      described_class.new.perform(bot.id, 12345, "Hello!")

      event = TelegramBotEngine::Event.last
      expect(event.event_type).to eq("delivery")
      expect(event.action).to eq("delivered")
      expect(event.chat_id).to eq(12345)
    end

    context "when the user blocked the bot" do
      before do
        # Stub the cached client instance the job will reuse (same bot id).
        allow(TelegramBotEngine.client_for(bot))
          .to receive(:send_message).and_raise(Telegram::Bot::Forbidden, "bot was blocked")
      end

      it "deactivates the subscription" do
        sub = create(:subscription, chat_id: 12345, active: true)

        described_class.new.perform(bot.id, 12345, "Hello!")

        expect(sub.reload.active).to be false
      end

      it "handles a missing subscription gracefully" do
        expect { described_class.new.perform(bot.id, 99999, "Hello!") }.not_to raise_error
      end

      it "logs a blocked event" do
        create(:subscription, chat_id: 12345, active: true)
        described_class.new.perform(bot.id, 12345, "Hello!")

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

    it "enqueues the job with the bot id first" do
      expect {
        described_class.perform_later(bot.id, 12345, "Hello!", {})
      }.to have_enqueued_job(described_class).with(bot.id, 12345, "Hello!", {})
    end
  end
end
