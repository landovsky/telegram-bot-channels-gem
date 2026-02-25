# frozen_string_literal: true

RSpec.describe TelegramBotEngine::Admin::AllowlistController, type: :controller do
  routes { TelegramBotEngine::Engine.routes }
  render_views

  before do
    TelegramBotEngine.configure do |c|
      c.admin_enabled = true
      c.allowed_usernames = :database
    end
  end

  describe "GET #index" do
    it "responds successfully" do
      get :index
      expect(response).to be_successful
    end

    it "displays allowed users ordered by username" do
      create(:allowed_user, username: "bob")
      create(:allowed_user, username: "alice")

      get :index

      body = response.body
      expect(body).to include("alice")
      expect(body).to include("bob")
      # Alice should appear before Bob (ordered by username)
      expect(body.index("alice")).to be < body.index("bob")
    end
  end

  describe "POST #create" do
    it "creates a new allowed user" do
      expect {
        post :create, params: { allowed_user: { username: "new_user", note: "Dev" } }
      }.to change(TelegramBotEngine::AllowedUser, :count).by(1)
    end

    it "redirects to allowlist index" do
      post :create, params: { allowed_user: { username: "new_user" } }
      expect(response).to redirect_to(admin_allowlist_index_path)
    end

    it "sets success notice" do
      post :create, params: { allowed_user: { username: "new_user" } }
      expect(flash[:notice]).to include("added")
    end

    it "handles duplicate username" do
      create(:allowed_user, username: "existing")

      post :create, params: { allowed_user: { username: "existing" } }

      expect(response).to redirect_to(admin_allowlist_index_path)
      expect(flash[:alert]).to be_present
    end

    it "handles blank username" do
      post :create, params: { allowed_user: { username: "" } }

      expect(response).to redirect_to(admin_allowlist_index_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE #destroy" do
    it "deletes the allowed user" do
      user = create(:allowed_user)

      expect {
        delete :destroy, params: { id: user.id }
      }.to change(TelegramBotEngine::AllowedUser, :count).by(-1)
    end

    it "redirects to allowlist index" do
      user = create(:allowed_user)

      delete :destroy, params: { id: user.id }

      expect(response).to redirect_to(admin_allowlist_index_path)
    end

    it "sets flash notice" do
      user = create(:allowed_user)

      delete :destroy, params: { id: user.id }

      expect(flash[:notice]).to include("removed")
    end
  end

  context "when not in database mode" do
    before do
      TelegramBotEngine.configure do |c|
        c.admin_enabled = true
        c.allowed_usernames = %w[alice bob]
      end
    end

    it "redirects index to dashboard" do
      get :index
      expect(response).to redirect_to(admin_dashboard_path)
    end

    it "redirects create to dashboard" do
      post :create, params: { allowed_user: { username: "test" } }
      expect(response).to redirect_to(admin_dashboard_path)
    end
  end
end
