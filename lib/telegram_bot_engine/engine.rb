# frozen_string_literal: true

module TelegramBotEngine
  class Engine < ::Rails::Engine
    isolate_namespace TelegramBotEngine

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "telegram_bot_engine.middleware" do |app|
      if app.config.api_only
        app.middleware.use ActionDispatch::Cookies
        app.middleware.use ActionDispatch::Session::CookieStore
        app.middleware.use ActionDispatch::Flash
      end
    end
  end
end
