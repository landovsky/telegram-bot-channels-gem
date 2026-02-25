# frozen_string_literal: true

TelegramBotEngine::Engine.routes.draw do
  scope module: :admin, as: :admin do
    root to: "dashboard#show"
    get "dashboard", to: "dashboard#show", as: :dashboard
    resources :subscriptions, only: %i[index update destroy]
    resources :allowlist, only: %i[index create destroy]
  end
end
