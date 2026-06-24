# frozen_string_literal: true

FactoryBot.define do
  factory :bot, class: "TelegramBotEngine::Bot" do
    sequence(:name) { |n| "Bot #{n}" }
    sequence(:slug) { |n| "bot-#{n}" }
    sequence(:token) { |n| "token-#{n}" }
    sequence(:webhook_id) { |n| "whid-#{n}" }
    sequence(:webhook_secret) { |n| "secret-#{n}" }
    active { true }
    default { false }

    # The back-compat anchor bot. Only one default may exist at a time.
    trait :default do
      name { "Default" }
      slug { "default" }
      default { true }
    end
  end
end
