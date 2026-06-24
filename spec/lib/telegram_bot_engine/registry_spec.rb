# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Registry do
  # The registry exists to fill telegram-bot's runtime gap, so test it against the
  # real Client/ClientStub rather than a double.
  around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

  let(:bot) { create(:bot, :default, token: "token-a") }

  it "caches one client per bot id" do
    expect(described_class.client_for(bot)).to be(described_class.client_for(bot))
  end

  it "resolves a distinct client per bot" do
    other = create(:bot, slug: "assistant", token: "token-b")
    expect(described_class.client_for(bot)).not_to be(described_class.client_for(other))
  end

  it "builds the client from the bot's own token" do
    expect(described_class.client_for(bot).token).to eq("token-a")
  end

  context "token rotation — a saved Bot must never serve a stale client" do
    it "rebuilds the client with the new token after the bot is updated" do
      original = described_class.client_for(bot)

      bot.update!(token: "rotated-token")

      rebuilt = described_class.client_for(bot)
      expect(rebuilt).not_to be(original)
      expect(rebuilt.token).to eq("rotated-token")
    end
  end

  it "drops a bot's client on #invalidate" do
    original = described_class.client_for(bot)
    described_class.invalidate(bot)
    expect(described_class.client_for(bot)).not_to be(original)
  end
end
