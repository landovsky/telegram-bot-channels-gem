# frozen_string_literal: true

module TelegramBotEngine
  class Engine < ::Rails::Engine
    isolate_namespace TelegramBotEngine

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "telegram_bot_engine.middleware" do |app|
      if app.config.api_only
        app.middleware.insert_before 0, ActionDispatch::Cookies
        app.middleware.insert_after ActionDispatch::Cookies, ActionDispatch::Session::CookieStore
        app.middleware.insert_after ActionDispatch::Session::CookieStore, ActionDispatch::Flash
      end
    end
  end
end
