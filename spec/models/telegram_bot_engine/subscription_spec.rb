# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Subscription do
  describe "validations" do
    it "requires chat_id" do
      subscription = described_class.new(chat_id: nil)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:chat_id]).to include("can't be blank")
    end

    it "requires unique chat_id" do
      create(:subscription, chat_id: 12345)
      duplicate = build(:subscription, chat_id: 12345)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:chat_id]).to include("has already been taken")
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
