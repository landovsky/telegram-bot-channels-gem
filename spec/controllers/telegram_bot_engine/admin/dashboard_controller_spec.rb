# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Admin::DashboardController, type: :controller do
  routes { TelegramBotEngine::Engine.routes }
  render_views

  let(:bot_client) { instance_double("Telegram::Bot::Client", username: "test_bot") }

  before do
    allow(Telegram).to receive(:bot).and_return(bot_client)
    TelegramBotEngine.configure { |c| c.admin_enabled = true }
  end

  describe "GET #show" do
    it "responds successfully" do
      get :show
      expect(response).to be_successful
    end

    it "displays subscription counts in the response body" do
      create(:subscription, active: true)
      create(:subscription, active: true)
      create(:subscription, active: false)

      get :show

      expect(response.body).to include("3") # total
      expect(response.body).to include("2") # active
      expect(response.body).to include("1") # inactive
    end

    it "displays bot username" do
      get :show
      expect(response.body).to include("test_bot")
      expect(response.body).to include("t.me/test_bot")
    end

    it "handles bot client errors gracefully" do
      allow(Telegram).to receive(:bot).and_raise(StandardError)
      get :show
      expect(response).to be_successful
    end

    context "when admin is disabled" do
      before do
        TelegramBotEngine.configure { |c| c.admin_enabled = false }
      end

      it "raises routing error" do
        expect { get :show }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
