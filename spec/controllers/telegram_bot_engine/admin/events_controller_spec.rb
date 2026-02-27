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
