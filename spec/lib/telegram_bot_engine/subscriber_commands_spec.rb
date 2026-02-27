# frozen_string_literal: true

RSpec.describe TelegramBotEngine::SubscriberCommands do
  # Build a minimal test class that simulates controller behavior
  # Define before_action before include so the concern's `included` block works
  let(:controller_class) do
    Class.new do
      def self.before_action(*); end

      include TelegramBotEngine::SubscriberCommands

      attr_accessor :chat_data, :from_data, :responses

      def initialize(chat_data: {}, from_data: {})
        @chat_data = chat_data
        @from_data = from_data
        @responses = []
      end

      def chat
        chat_data
      end

      def from
        from_data
      end

      def respond_with(_type, **options)
        @responses << options
      end

      # Custom command for testing available_commands_text
      def custom!(*); end
    end
  end

  let(:authorized_from) { { "id" => 12345, "username" => "alice", "first_name" => "Alice" } }
  let(:chat) { { "id" => 99999 } }

  before do
    TelegramBotEngine.configure do |c|
      c.allowed_usernames = %w[alice]
    end
  end

  describe "#start!" do
    let(:controller) { controller_class.new(chat_data: chat, from_data: authorized_from) }

    it "creates a new subscription" do
      expect { controller.start! }.to change(TelegramBotEngine::Subscription, :count).by(1)
    end

    it "stores subscription attributes" do
      controller.start!
      sub = TelegramBotEngine::Subscription.last

      expect(sub.chat_id).to eq(99999)
      expect(sub.user_id).to eq(12345)
      expect(sub.username).to eq("alice")
      expect(sub.first_name).to eq("Alice")
      expect(sub.active).to be true
    end

    it "reactivates an existing inactive subscription" do
      sub = create(:subscription, chat_id: 99999, active: false)
      controller.start!

      sub.reload
      expect(sub.active).to be true
      expect(sub.username).to eq("alice")
    end

    it "responds with welcome message containing username" do
      controller.start!

      expect(controller.responses.length).to eq(1)
      expect(controller.responses.first[:text]).to include("Alice")
    end

    it "interpolates commands in welcome message" do
      controller.start!

      text = controller.responses.first[:text]
      expect(text).to include("/start")
      expect(text).to include("/stop")
      expect(text).to include("/help")
    end

    it "logs a start event" do
      controller.start!

      event = TelegramBotEngine::Event.last
      expect(event.event_type).to eq("command")
      expect(event.action).to eq("start")
      expect(event.chat_id).to eq(99999)
      expect(event.username).to eq("alice")
    end
  end

  describe "#stop!" do
    let(:controller) { controller_class.new(chat_data: chat, from_data: authorized_from) }

    it "deactivates existing subscription" do
      sub = create(:subscription, chat_id: 99999, active: true)
      controller.stop!

      sub.reload
      expect(sub.active).to be false
    end

    it "handles missing subscription gracefully" do
      expect { controller.stop! }.not_to raise_error
    end

    it "responds with unsubscribed message" do
      create(:subscription, chat_id: 99999)
      controller.stop!

      expect(controller.responses.first[:text]).to include("unsubscribed")
    end

    it "logs a stop event" do
      create(:subscription, chat_id: 99999)
      controller.stop!

      event = TelegramBotEngine::Event.last
      expect(event.event_type).to eq("command")
      expect(event.action).to eq("stop")
      expect(event.chat_id).to eq(99999)
    end
  end

  describe "#help!" do
    let(:controller) { controller_class.new(chat_data: chat, from_data: authorized_from) }

    it "responds with available commands" do
      controller.help!

      text = controller.responses.first[:text]
      expect(text).to include("/start")
      expect(text).to include("/stop")
      expect(text).to include("/help")
      expect(text).to include("/custom")
    end

    it "logs a help event" do
      controller.help!

      event = TelegramBotEngine::Event.last
      expect(event.event_type).to eq("command")
      expect(event.action).to eq("help")
    end
  end

  describe "#authorize_user! (private)" do
    context "when user is authorized" do
      let(:controller) { controller_class.new(chat_data: chat, from_data: authorized_from) }

      it "returns without responding" do
        controller.send(:authorize_user!)
        expect(controller.responses).to be_empty
      end
    end

    context "when user is unauthorized" do
      let(:controller) do
        controller_class.new(
          chat_data: chat,
          from_data: { "id" => 99, "username" => "eve", "first_name" => "Eve" }
        )
      end

      it "responds with unauthorized message and throws :abort" do
        expect {
          controller.send(:authorize_user!)
        }.to throw_symbol(:abort)

        expect(controller.responses.first[:text]).to eq(TelegramBotEngine.config.unauthorized_message)
      end

      it "logs an auth_failure event" do
        catch(:abort) { controller.send(:authorize_user!) }

        event = TelegramBotEngine::Event.last
        expect(event.event_type).to eq("auth_failure")
        expect(event.action).to eq("unauthorized")
        expect(event.username).to eq("eve")
      end
    end
  end

  describe "#available_commands_text (private)" do
    let(:controller) { controller_class.new(chat_data: chat, from_data: authorized_from) }

    it "includes engine commands and host app commands" do
      text = controller.send(:available_commands_text)

      expect(text).to include("/start")
      expect(text).to include("/stop")
      expect(text).to include("/help")
      expect(text).to include("/custom")
    end

    it "de-duplicates commands" do
      text = controller.send(:available_commands_text)
      lines = text.split("\n")

      expect(lines.count("/start")).to eq(1)
    end
  end
end
