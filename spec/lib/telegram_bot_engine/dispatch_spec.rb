# frozen_string_literal: true

require "rack/mock"

RSpec.describe TelegramBotEngine::Dispatch do
  around { |example| Telegram::Bot::ClientStub.stub_all! { example.run } }

  # Stand-in for the host's Telegram::Bot::UpdatesController (the SubscriberCommands host).
  let(:capturing_controller) do
    Class.new do
      class << self
        attr_accessor :calls

        def dispatch(bot, update, request)
          (self.calls ||= []) << { bot: bot, update: update, request: request }
          nil
        end
      end
    end
  end

  let(:update) { { "update_id" => 1, "message" => { "text" => "/start", "chat" => { "id" => 7 } } } }

  before do
    stub_const("CapturingController", capturing_controller)
    TelegramBotEngine.configure do |c|
      c.auto_register_webhooks = false
      c.dispatch_controller = "CapturingController"
    end
  end

  # The path segment is the NON-secret webhook_id; the secret_token goes in the header.
  def post_env(webhook_id, secret_token:, body: nil, raw: nil)
    Rack::MockRequest.env_for(
      "/#{webhook_id}",
      method: "POST",
      input: raw || (body || update).to_json,
      "CONTENT_TYPE" => "application/json",
      "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN" => secret_token
    )
  end

  context "the inbound 'right bot' guarantee" do
    it "routes by webhook_id to the right bot's OWN client, authenticating via the header secret" do
      default_bot = create(:bot, :default, webhook_id: "wid-default", webhook_secret: "sek-default", token: "default-tok")
      assistant   = create(:bot, slug: "assistant", webhook_id: "wid-assistant", webhook_secret: "sek-assistant", token: "assistant-tok")

      status, = described_class.call(post_env("wid-assistant", secret_token: "sek-assistant"))

      expect(status).to eq(200)
      call = CapturingController.calls.last
      expect(call[:bot]).to eq(TelegramBotEngine.client_for(assistant))
      expect(call[:bot]).not_to eq(TelegramBotEngine.client_for(default_bot))
      expect(call[:bot].token).to eq("assistant-tok")
      expect(call[:update]).to include("update_id" => 1)
    end

    it "exposes the resolved Bot in request.env so SubscriberCommands can scope per bot" do
      assistant = create(:bot, slug: "assistant", webhook_id: "wid", webhook_secret: "sek")

      described_class.call(post_env("wid", secret_token: "sek"))

      expect(CapturingController.calls.last[:request].env["telegram_bot_engine.bot"]).to eq(assistant)
    end
  end

  context "authentication and resolution" do
    it "returns 404 for an unknown webhook_id" do
      status, = described_class.call(post_env("nope", secret_token: "nope"))
      expect(status).to eq(404)
    end

    it "returns 404 for an inactive bot (its webhook should already be removed)" do
      create(:bot, slug: "off", webhook_id: "offwid", webhook_secret: "offsek", active: false)
      status, = described_class.call(post_env("offwid", secret_token: "offsek"))
      expect(status).to eq(404)
    end

    it "returns 403 when the secret-token header does not match (telegram-bot 0.16 omits this check)" do
      create(:bot, :default, webhook_id: "realwid", webhook_secret: "realsecret")

      status, = described_class.call(post_env("realwid", secret_token: "WRONG"))

      expect(status).to eq(403)
      expect(CapturingController.calls).to be_nil
    end

    it "returns 403 when the secret-token header is absent" do
      create(:bot, :default, webhook_id: "realwid", webhook_secret: "realsecret")
      env = post_env("realwid", secret_token: "x")
      env.delete("HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN")

      status, = described_class.call(env)
      expect(status).to eq(403)
    end

    it "returns 503 when no dispatch_controller is configured" do
      TelegramBotEngine.configure { |c| c.dispatch_controller = nil }
      create(:bot, :default, webhook_id: "realwid", webhook_secret: "realsecret")

      status, = described_class.call(post_env("realwid", secret_token: "realsecret"))
      expect(status).to eq(503)
    end

    it "rejects non-POST methods" do
      status, = described_class.call(Rack::MockRequest.env_for("/whatever", method: "GET"))
      expect(status).to eq(405)
    end

    it "returns a clean 400 (not an unhandled 500) for a malformed JSON body from an authenticated caller" do
      create(:bot, :default, webhook_id: "realwid", webhook_secret: "realsecret")

      status, = described_class.call(post_env("realwid", secret_token: "realsecret", raw: "{not json"))

      expect(status).to eq(400)
      expect(CapturingController.calls).to be_nil
    end
  end
end
