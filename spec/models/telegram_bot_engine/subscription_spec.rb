# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Subscription do
  describe "validations" do
    it "requires chat_id" do
      subscription = described_class.new(chat_id: nil)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:chat_id]).to include("can't be blank")
    end

    it "requires chat_id unique within a bot" do
      create(:subscription, chat_id: 12345)
      duplicate = build(:subscription, chat_id: 12345)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:chat_id]).to include("has already been taken")
    end

    context "per-bot subscribers — the same chat may subscribe to more than one bot" do
      it "allows the same chat_id under a different bot" do
        assistant = create(:bot, slug: "assistant")
        create(:subscription, chat_id: 12345) # default/legacy audience (nil bot_id)
        cross_bot = build(:subscription, chat_id: 12345, bot: assistant)
        expect(cross_bot).to be_valid
      end
    end

    it "is valid with required attributes" do
      subscription = build(:subscription)
      expect(subscription).to be_valid
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active subscriptions" do
        active = create(:subscription, active: true)
        _inactive = create(:subscription, active: false)

        expect(described_class.active).to eq([active])
      end
    end

    describe ".for_bot" do
      it "scopes to a non-default bot's own subscribers only" do
        assistant = create(:bot, slug: "assistant")
        mine = create(:subscription, chat_id: 1, bot: assistant)
        _legacy = create(:subscription, chat_id: 2) # nil bot_id
        expect(described_class.for_bot(assistant)).to eq([mine])
      end

      context "back-compat — nil-bot_id subscribers belong to the default bot" do
        it "includes legacy nil-bot_id rows alongside the default bot's own rows" do
          default_bot = create(:bot, :default)
          legacy = create(:subscription, chat_id: 1) # nil bot_id (pre-multi-bot)
          owned  = create(:subscription, chat_id: 2, bot: default_bot)
          create(:bot, slug: "assistant").tap { |a| create(:subscription, chat_id: 3, bot: a) }

          expect(described_class.for_bot(default_bot)).to match_array([legacy, owned])
        end
      end
    end
  end

  describe "defaults" do
    it "defaults active to true" do
      subscription = described_class.new
      expect(subscription.active).to be true
    end

    it "defaults metadata to empty hash" do
      subscription = described_class.new
      expect(subscription.metadata).to eq({})
    end
  end

  describe "attributes" do
    it "stores all expected attributes" do
      subscription = create(:subscription,
        chat_id: 99999,
        user_id: 88888,
        username: "testuser",
        first_name: "Test",
        active: true,
        metadata: { "key" => "value" }
      )

      subscription.reload
      expect(subscription.chat_id).to eq(99999)
      expect(subscription.user_id).to eq(88888)
      expect(subscription.username).to eq("testuser")
      expect(subscription.first_name).to eq("Test")
      expect(subscription.active).to be true
      expect(subscription.metadata).to eq({ "key" => "value" })
    end
  end
end
