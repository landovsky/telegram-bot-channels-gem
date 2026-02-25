# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Authorizer do
  describe ".authorized?" do
    context "when allowed_usernames is nil (open access)" do
      before do
        TelegramBotEngine.configure { |c| c.allowed_usernames = nil }
      end

      it "authorizes any username" do
        expect(described_class.authorized?("anyone")).to be true
      end

      it "authorizes nil username" do
        expect(described_class.authorized?(nil)).to be true
      end
    end

    context "when allowed_usernames is an array" do
      before do
        TelegramBotEngine.configure { |c| c.allowed_usernames = %w[alice bob] }
      end

      it "authorizes listed usernames" do
        expect(described_class.authorized?("alice")).to be true
        expect(described_class.authorized?("bob")).to be true
      end

      it "rejects unlisted usernames" do
        expect(described_class.authorized?("eve")).to be false
      end

      it "is case-insensitive" do
        expect(described_class.authorized?("Alice")).to be true
        expect(described_class.authorized?("ALICE")).to be true
      end

      it "rejects nil username" do
        expect(described_class.authorized?(nil)).to be false
      end
    end

    context "when allowed_usernames is a proc" do
      before do
        TelegramBotEngine.configure do |c|
          c.allowed_usernames = -> { %w[dynamic_user] }
        end
      end

      it "calls the proc and checks result" do
        expect(described_class.authorized?("dynamic_user")).to be true
        expect(described_class.authorized?("other_user")).to be false
      end

      it "is case-insensitive" do
        expect(described_class.authorized?("Dynamic_User")).to be true
      end
    end

    context "when allowed_usernames is :database" do
      before do
        TelegramBotEngine.configure { |c| c.allowed_usernames = :database }
      end

      it "checks against AllowedUser records" do
        create(:allowed_user, username: "db_user")

        expect(described_class.authorized?("db_user")).to be true
        expect(described_class.authorized?("unknown")).to be false
      end

      it "is case-insensitive" do
        create(:allowed_user, username: "db_user")

        expect(described_class.authorized?("DB_User")).to be true
      end
    end

    context "when allowed_usernames is an unknown type" do
      before do
        TelegramBotEngine.configure { |c| c.allowed_usernames = "invalid" }
      end

      it "rejects all usernames" do
        expect(described_class.authorized?("anyone")).to be false
      end
    end
  end
end
