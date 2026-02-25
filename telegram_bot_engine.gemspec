# frozen_string_literal: true

require_relative "lib/telegram_bot_engine/version"

Gem::Specification.new do |spec|
  spec.name = "telegram_bot_engine"
  spec.version = TelegramBotEngine::VERSION
  spec.authors = ["TelegramBotEngine Contributors"]
  spec.summary = "Rails engine for Telegram bot subscriber management, authorization, broadcasting, and admin UI"
  spec.description = "A mountable Rails engine that adds subscriber persistence, authorization, " \
                     "broadcasting, and an admin UI on top of the telegram-bot gem."
  spec.homepage = "https://github.com/landovsky/telegram-bot-channels-gem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.files = Dir[
    "app/**/*",
    "config/**/*",
    "db/**/*",
    "lib/**/*",
    "LICENSE",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 7.0"
  spec.add_dependency "telegram-bot", "~> 0.16"
end
