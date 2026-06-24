# frozen_string_literal: true

# The headline multi-bot guarantee (docs/0001 §8): delivery picks the *right* bot.
# A host-app mock of TelegramBotEngine.broadcast cannot prove this — it is exactly
# why the test belongs in the gem. We assert against the chosen bot's ClientStub
# requests and prove no other bot's client was touched.
RSpec.describe "Bot-aware delivery routing", type: :model do
  include ActiveJob::TestHelper

  around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

  it "delivers a broadcast through the chosen bot and through no other bot" do
    default_bot = create(:bot, :default, token: "default-token")
    assistant   = create(:bot, slug: "assistant", token: "assistant-token")
    create(:subscription, chat_id: 555, active: true)

    perform_enqueued_jobs do
      TelegramBotEngine.broadcast("ping", bot: assistant)
    end

    expect(TelegramBotEngine.client_for(assistant).requests[:sendMessage])
      .to include(hash_including(chat_id: 555, text: "ping"))
    expect(TelegramBotEngine.client_for(default_bot).requests[:sendMessage]).to be_empty
  end

  it "a no-`bot:` broadcast still delivers through the default bot (back-compat)" do
    default_bot = create(:bot, :default, token: "default-token")
    create(:bot, slug: "assistant", token: "assistant-token")
    create(:subscription, chat_id: 777, active: true)

    perform_enqueued_jobs do
      TelegramBotEngine.broadcast("legacy")
    end

    expect(TelegramBotEngine.client_for(default_bot).requests[:sendMessage])
      .to include(hash_including(chat_id: 777, text: "legacy"))
  end
end
