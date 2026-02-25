# frozen_string_literal: true

FactoryBot.define do
  factory :subscription, class: "TelegramBotEngine::Subscription" do
    sequence(:chat_id) { |n| 100_000 + n }
    sequence(:user_id) { |n| 200_000 + n }
    sequence(:username) { |n| "user_#{n}" }
    first_name { "Test" }
    active { true }
    metadata { {} }
  end
end
