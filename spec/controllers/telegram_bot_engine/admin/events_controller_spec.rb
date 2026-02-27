# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Admin::EventsController, type: :controller do
  routes { TelegramBotEngine::Engine.routes }
  render_views

  before do
    TelegramBotEngine.configure { |c| c.admin_enabled = true }
  end

  describe "GET #index" do
    it "responds successfully" do
      get :index
      expect(response).to be_successful
    end

    it "displays events" do
      TelegramBotEngine::Event.create!(
        event_type: "command", action: "start",
        chat_id: 12345, username: "alice"
      )

      get :index

      expect(response.body).to include("command")
      expect(response.body).to include("start")
      expect(response.body).to include("alice")
      expect(response.body).to include("12345")
    end

    it "filters by event type" do
      TelegramBotEngine::Event.create!(event_type: "command", action: "start", username: "alice")
      TelegramBotEngine::Event.create!(event_type: "delivery", action: "broadcast", username: "system")

      get :index, params: { type: "command" }

      expect(response.body).to include("alice")
      expect(response.body).not_to include("system")
    end

    it "filters by action" do
      TelegramBotEngine::Event.create!(event_type: "command", action: "start", username: "alice")
      TelegramBotEngine::Event.create!(event_type: "command", action: "stop", username: "bob")

      get :index, params: { action_name: "start" }

      expect(response.body).to include("alice")
      expect(response.body).not_to include("bob")
    end

    it "filters by chat_id" do
      TelegramBotEngine::Event.create!(event_type: "command", action: "start", chat_id: 111, username: "alice")
      TelegramBotEngine::Event.create!(event_type: "command", action: "start", chat_id: 222, username: "bob")

      get :index, params: { chat_id: "111" }

      expect(response.body).to include("alice")
      expect(response.body).not_to include("bob")
    end

    it "paginates results" do
      55.times do |i|
        TelegramBotEngine::Event.create!(event_type: "command", action: "start", username: "user_#{i}")
      end

      get :index
      expect(response.body).to include("Page 1 of 2")
      expect(response.body).to include("Next")

      get :index, params: { page: 2 }
      expect(response.body).to include("Page 2 of 2")
      expect(response.body).to include("Previous")
    end

    it "shows empty state" do
      get :index
      expect(response.body).to include("No events found")
    end

    context "JSON format" do
      it "responds with JSON" do
        TelegramBotEngine::Event.create!(
          event_type: "command", action: "start",
          chat_id: 12345, username: "alice", details: { text: "hello" }
        )

        get :index, format: :json

        expect(response).to be_successful
        expect(response.content_type).to include("application/json")

        body = JSON.parse(response.body)
        expect(body["events"].length).to eq(1)
        expect(body["events"][0]["event_type"]).to eq("command")
        expect(body["events"][0]["action"]).to eq("start")
        expect(body["events"][0]["chat_id"]).to eq(12345)
        expect(body["events"][0]["username"]).to eq("alice")
        expect(body["events"][0]["details"]).to eq("text" => "hello")
        expect(body["events"][0]["created_at"]).to be_present
        expect(body["meta"]["total_count"]).to eq(1)
        expect(body["meta"]["page"]).to eq(1)
        expect(body["meta"]["per_page"]).to eq(50)
      end

      it "filters by type" do
        TelegramBotEngine::Event.create!(event_type: "command", action: "start")
        TelegramBotEngine::Event.create!(event_type: "delivery", action: "broadcast")

        get :index, format: :json, params: { type: "command" }

        body = JSON.parse(response.body)
        expect(body["events"].length).to eq(1)
        expect(body["events"][0]["event_type"]).to eq("command")
        expect(body["meta"]["total_count"]).to eq(1)
      end

      it "paginates" do
        55.times { TelegramBotEngine::Event.create!(event_type: "command", action: "start") }

        get :index, format: :json, params: { page: 2 }

        body = JSON.parse(response.body)
        expect(body["events"].length).to eq(5)
        expect(body["meta"]["page"]).to eq(2)
        expect(body["meta"]["total_pages"]).to eq(2)
        expect(body["meta"]["total_count"]).to eq(55)
      end
    end

    context "when admin is disabled" do
      before do
        TelegramBotEngine.configure { |c| c.admin_enabled = false }
      end

      it "raises routing error" do
        expect { get :index }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
