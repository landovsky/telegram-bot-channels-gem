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

    context "when bots-as-data rows exist (multi-bot dashboard, §3.8)" do
      it "lists each bot with its own active subscriber count instead of the single-bot card" do
        default_bot = create(:bot, :default, name: "Primary")
        assistant = create(:bot, slug: "assistant", name: "Assistant")
        create(:subscription, bot: assistant, active: true)
        create(:subscription, bot: default_bot, active: true)

        get :show

        expect(response.body).to include("Primary")
        expect(response.body).to include("Assistant")
        expect(response.body).to include("assistant") # slug rendered
      end
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
