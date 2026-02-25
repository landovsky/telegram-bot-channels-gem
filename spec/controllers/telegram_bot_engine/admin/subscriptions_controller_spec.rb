# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Admin::SubscriptionsController, type: :controller do
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

    it "displays all subscriptions" do
      create(:subscription, username: "older_user", created_at: 2.days.ago)
      create(:subscription, username: "newer_user", created_at: 1.day.ago)

      get :index

      body = response.body
      expect(body).to include("older_user")
      expect(body).to include("newer_user")
      # Newer should appear first (ordered by created_at desc)
      expect(body.index("newer_user")).to be < body.index("older_user")
    end
  end

  describe "PATCH #update" do
    it "toggles subscription from active to inactive" do
      subscription = create(:subscription, active: true)

      patch :update, params: { id: subscription.id }

      subscription.reload
      expect(subscription.active).to be false
    end

    it "toggles subscription from inactive to active" do
      subscription = create(:subscription, active: false)

      patch :update, params: { id: subscription.id }

      subscription.reload
      expect(subscription.active).to be true
    end

    it "redirects to subscriptions index" do
      subscription = create(:subscription)

      patch :update, params: { id: subscription.id }

      expect(response).to redirect_to(admin_subscriptions_path)
    end

    it "sets a flash notice" do
      subscription = create(:subscription, active: true)

      patch :update, params: { id: subscription.id }

      expect(flash[:notice]).to include("deactivated")
    end
  end

  describe "DELETE #destroy" do
    it "deletes the subscription" do
      subscription = create(:subscription)

      expect {
        delete :destroy, params: { id: subscription.id }
      }.to change(TelegramBotEngine::Subscription, :count).by(-1)
    end

    it "redirects to subscriptions index" do
      subscription = create(:subscription)

      delete :destroy, params: { id: subscription.id }

      expect(response).to redirect_to(admin_subscriptions_path)
    end

    it "sets a flash notice" do
      subscription = create(:subscription)

      delete :destroy, params: { id: subscription.id }

      expect(flash[:notice]).to include("deleted")
    end
  end
end
