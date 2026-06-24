# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Admin::BotsController, type: :controller do
  routes { TelegramBotEngine::Engine.routes }
  render_views

  before do
    TelegramBotEngine.configure { |c| c.admin_enabled = true }
  end

  describe "GET #index" do
    it "responds successfully and lists bots" do
      create(:bot, :default, name: "Primary")
      create(:bot, slug: "assistant", name: "Assistant")

      get :index

      expect(response).to be_successful
      expect(response.body).to include("Primary")
      expect(response.body).to include("Assistant")
    end

    it "never renders a full token in the listing" do
      create(:bot, :default, token: "123456:SUPERSECRETTOKEN")
      get :index
      expect(response.body).not_to include("SUPERSECRETTOKEN")
      expect(response.body).to include("••••")
    end
  end

  describe "GET #new" do
    it "responds successfully" do
      get :new
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    it "creates a bot and redirects with a notice" do
      expect {
        post :create, params: { bot: { name: "Assistant", slug: "assistant", token: "tok", active: "1" } }
      }.to change(TelegramBotEngine::Bot, :count).by(1)

      expect(response).to redirect_to(admin_bots_path)
      expect(flash[:notice]).to include("created")
    end

    it "re-renders with an alert when the token is missing" do
      expect {
        post :create, params: { bot: { name: "Assistant", slug: "assistant", token: "" } }
      }.not_to change(TelegramBotEngine::Bot, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash.now[:alert]).to be_present
    end

    it "promoting a new default demotes the old one" do
      old = create(:bot, :default)
      post :create, params: { bot: { name: "New", slug: "new", token: "tok", default: "1", active: "1" } }

      expect(old.reload.default).to be false
      expect(TelegramBotEngine::Bot.where(default: true).count).to eq(1)
    end
  end

  describe "GET #edit" do
    it "responds successfully" do
      bot = create(:bot, :default)
      get :edit, params: { id: bot.id }
      expect(response).to be_successful
    end
  end

  describe "PATCH #update" do
    it "updates editable attributes and redirects" do
      bot = create(:bot, :default, name: "Old")
      patch :update, params: { id: bot.id, bot: { name: "New", slug: bot.slug } }

      expect(bot.reload.name).to eq("New")
      expect(response).to redirect_to(admin_bots_path)
    end

    it "never blanks the token via a normal edit (rotation is a separate action)" do
      bot = create(:bot, :default, token: "original-token")
      patch :update, params: { id: bot.id, bot: { name: "Renamed", slug: bot.slug } }

      expect(bot.reload.token).to eq("original-token")
    end

    it "refuses to demote the only default bot via the edit form (back-compat anchor)" do
      bot = create(:bot, :default)

      patch :update, params: { id: bot.id, bot: { name: bot.name, slug: bot.slug, default: "0" } }

      expect(bot.reload.default).to be true
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH #rotate_token" do
    it "rotates the token when a new one is supplied" do
      bot = create(:bot, :default, token: "old")
      patch :rotate_token, params: { id: bot.id, token: "brand-new" }

      expect(bot.reload.token).to eq("brand-new")
      expect(flash[:notice]).to include("rotated")
    end

    it "refuses an empty token" do
      bot = create(:bot, :default, token: "old")
      patch :rotate_token, params: { id: bot.id, token: "" }

      expect(bot.reload.token).to eq("old")
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE #destroy" do
    it "deletes a non-default bot" do
      bot = create(:bot, slug: "assistant")

      expect {
        delete :destroy, params: { id: bot.id }
      }.to change(TelegramBotEngine::Bot, :count).by(-1)
    end

    context "the default bot is the back-compat anchor and must not be deletable" do
      it "refuses to delete the default bot" do
        bot = create(:bot, :default)

        expect {
          delete :destroy, params: { id: bot.id }
        }.not_to change(TelegramBotEngine::Bot, :count)

        expect(flash[:alert]).to include("Cannot delete the default bot")
      end
    end
  end

  context "when admin is disabled" do
    before { TelegramBotEngine.configure { |c| c.admin_enabled = false } }

    it "raises routing error" do
      expect { get :index }.to raise_error(ActionController::RoutingError)
    end
  end
end
