# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "defaults allowed_usernames to nil" do
      expect(config.allowed_usernames).to be_nil
    end

    it "defaults admin_enabled to true" do
      expect(config.admin_enabled).to be true
    end

    it "defaults unauthorized_message" do
      expect(config.unauthorized_message).to eq("Sorry, you're not authorized to use this bot.")
    end

    it "defaults welcome_message with interpolation placeholders" do
      expect(config.welcome_message).to include("%{username}")
      expect(config.welcome_message).to include("%{commands}")
    end
  end

  describe "configure block" do
    it "allows setting all attributes" do
      TelegramBotEngine.configure do |c|
        c.allowed_usernames = %w[user1 user2]
        c.admin_enabled = false
        c.unauthorized_message = "No access"
        c.welcome_message = "Hi %{username}"
      end

      config = TelegramBotEngine.config
      expect(config.allowed_usernames).to eq(%w[user1 user2])
      expect(config.admin_enabled).to be false
      expect(config.unauthorized_message).to eq("No access")
      expect(config.welcome_message).to eq("Hi %{username}")
    end

    it "supports array allowlist" do
      TelegramBotEngine.configure do |c|
        c.allowed_usernames = %w[alice bob]
      end

      expect(TelegramBotEngine.config.allowed_usernames).to eq(%w[alice bob])
    end

    it "supports proc allowlist" do
      proc_list = -> { %w[dynamic_user] }

      TelegramBotEngine.configure do |c|
        c.allowed_usernames = proc_list
      end

      expect(TelegramBotEngine.config.allowed_usernames).to be_a(Proc)
      expect(TelegramBotEngine.config.allowed_usernames.call).to eq(%w[dynamic_user])
    end

    it "supports :database allowlist" do
      TelegramBotEngine.configure do |c|
        c.allowed_usernames = :database
      end

      expect(TelegramBotEngine.config.allowed_usernames).to eq(:database)
    end
  end

  describe ".reset_config!" do
    it "resets to defaults" do
      TelegramBotEngine.configure do |c|
        c.allowed_usernames = %w[user1]
        c.admin_enabled = false
      end

      TelegramBotEngine.reset_config!

      expect(TelegramBotEngine.config.allowed_usernames).to be_nil
      expect(TelegramBotEngine.config.admin_enabled).to be true
    end
  end
end
