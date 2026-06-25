# frozen_string_literal: true

require_relative "lib/telegram_bot_engine/version"

Gem::Specification.new do |spec|
  spec.name = "telegram_bot_engine"
  spec.version = TelegramBotEngine::VERSION
  spec.authors = ["Tomáš Landovský"]
  spec.email = ["landovsky@gmail.com"]
  spec.summary = "Rails engine for Telegram bot subscriber management, authorization, broadcasting, and admin UI"
  spec.description = "A mountable Rails engine that adds subscriber persistence, authorization, " \
                     "broadcasting, and an admin UI on top of the telegram-bot gem."
  spec.homepage = "https://github.com/landovsky/telegram-bot-channels-gem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "app/**/*",
    "config/**/*",
    "db/**/*",
    "lib/**/*",
    "CHANGELOG.md",
    "LICENSE",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  # Upper-bounded so a future incompatible Rails major can't resolve. telegram-bot 0.16
  # transitively caps actionpack at < 8.1, but the explicit ceiling clears the open-ended
  # build warning and documents the supported range (Rails 7.x and 8.x).
  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "telegram-bot", "~> 0.16"
end
