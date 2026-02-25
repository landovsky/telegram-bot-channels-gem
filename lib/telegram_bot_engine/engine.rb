# frozen_string_literal: true

module TelegramBotEngine
  class Engine < ::Rails::Engine
    isolate_namespace TelegramBotEngine

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
