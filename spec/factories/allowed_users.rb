# frozen_string_literal: true

FactoryBot.define do
  factory :allowed_user, class: "TelegramBotEngine::AllowedUser" do
    sequence(:username) { |n| "allowed_user_#{n}" }
    note { nil }
  end
end
