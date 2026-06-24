# frozen_string_literal: true

RSpec.describe TelegramBotEngine::AllowedUser do
  describe "validations" do
    it "requires username" do
      user = described_class.new(username: nil)
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("can't be blank")
    end

    it "requires unique username" do
      create(:allowed_user, username: "testuser")
      duplicate = build(:allowed_user, username: "testuser")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:username]).to include("has already been taken")
    end

    it "is valid with required attributes" do
      user = build(:allowed_user)
      expect(user).to be_valid
    end

    context "per-bot allowlist — the same username may be allow-listed under different bots" do
      it "allows the same username globally and scoped to a bot" do
        assistant = create(:bot, slug: "assistant")
        create(:allowed_user, username: "tom", bot: nil)
        scoped = build(:allowed_user, username: "tom", bot: assistant)
        expect(scoped).to be_valid
      end
    end
  end

  describe ".for_bot" do
    it "returns global (nil bot_id) entries plus that bot's own entries" do
      assistant = create(:bot, slug: "assistant")
      _other = create(:bot, slug: "other")
      global = create(:allowed_user, username: "global", bot: nil)
      mine = create(:allowed_user, username: "mine", bot: assistant)
      create(:allowed_user, username: "theirs", bot: _other)

      expect(described_class.for_bot(assistant)).to match_array([global, mine])
    end
  end

  describe "attributes" do
    it "stores username and note" do
      user = create(:allowed_user, username: "dev_user", note: "Developer")
      user.reload
      expect(user.username).to eq("dev_user")
      expect(user.note).to eq("Developer")
    end

    it "allows nil note" do
      user = create(:allowed_user, note: nil)
      expect(user).to be_valid
    end
  end
end
