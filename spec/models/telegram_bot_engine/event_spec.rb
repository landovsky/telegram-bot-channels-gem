# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Event do
  describe "validations" do
    it "requires event_type" do
      event = described_class.new(event_type: nil, action: "start")
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to include("can't be blank")
    end

    it "requires action" do
      event = described_class.new(event_type: "command", action: nil)
      expect(event).not_to be_valid
      expect(event.errors[:action]).to include("can't be blank")
    end

    it "is valid with required attributes" do
      event = described_class.new(event_type: "command", action: "start")
      expect(event).to be_valid
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        old_event = described_class.create!(event_type: "command", action: "start", created_at: 2.hours.ago)
        new_event = described_class.create!(event_type: "command", action: "stop", created_at: 1.hour.ago)

        expect(described_class.recent).to eq([new_event, old_event])
      end
    end

    describe ".by_type" do
      it "filters by event_type" do
        cmd = described_class.create!(event_type: "command", action: "start")
        _delivery = described_class.create!(event_type: "delivery", action: "broadcast")

        expect(described_class.by_type("command")).to eq([cmd])
      end

      it "returns all when type is blank" do
        described_class.create!(event_type: "command", action: "start")
        described_class.create!(event_type: "delivery", action: "broadcast")

        expect(described_class.by_type(nil).count).to eq(2)
        expect(described_class.by_type("").count).to eq(2)
      end
    end

    describe ".by_action" do
      it "filters by action" do
        start_event = described_class.create!(event_type: "command", action: "start")
        _stop_event = described_class.create!(event_type: "command", action: "stop")

        expect(described_class.by_action("start")).to eq([start_event])
      end
    end

    describe ".by_chat_id" do
      it "filters by chat_id" do
        event = described_class.create!(event_type: "command", action: "start", chat_id: 12345)
        _other = described_class.create!(event_type: "command", action: "start", chat_id: 99999)

        expect(described_class.by_chat_id(12345)).to eq([event])
      end
    end

    describe ".since" do
      it "returns events since given time" do
        _old = described_class.create!(event_type: "command", action: "start", created_at: 2.days.ago)
        recent = described_class.create!(event_type: "command", action: "stop", created_at: 1.hour.ago)

        expect(described_class.since(1.day.ago)).to eq([recent])
      end
    end
  end

  describe ".log" do
    it "creates an event" do
      expect {
        described_class.log(event_type: "command", action: "start", chat_id: 123, username: "alice")
      }.to change(described_class, :count).by(1)

      event = described_class.last
      expect(event.event_type).to eq("command")
      expect(event.action).to eq("start")
      expect(event.chat_id).to eq(123)
      expect(event.username).to eq("alice")
    end

    it "stores details" do
      described_class.log(event_type: "delivery", action: "broadcast", details: { subscriber_count: 5 })

      event = described_class.last
      expect(event.details).to eq("subscriber_count" => 5)
    end

    it "does not create event when event_logging is disabled" do
      TelegramBotEngine.configure { |c| c.event_logging = false }

      expect {
        described_class.log(event_type: "command", action: "start")
      }.not_to change(described_class, :count)
    end

    it "probabilistically triggers purge_old!" do
      allow(described_class).to receive(:purge_old_randomly!)
      described_class.log(event_type: "command", action: "start")
      expect(described_class).to have_received(:purge_old_randomly!)
    end
  end

  describe ".purge_old!" do
    it "deletes events older than retention period" do
      TelegramBotEngine.configure { |c| c.event_retention_days = 7 }

      old = described_class.create!(event_type: "command", action: "start", created_at: 8.days.ago)
      recent = described_class.create!(event_type: "command", action: "stop", created_at: 1.day.ago)

      described_class.purge_old!

      expect(described_class.find_by(id: old.id)).to be_nil
      expect(described_class.find_by(id: recent.id)).to eq(recent)
    end
  end
end
