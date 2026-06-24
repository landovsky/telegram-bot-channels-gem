# frozen_string_literal: true

TelegramBotEngine::Engine.routes.draw do
  scope module: :admin, as: :admin do
    root to: "dashboard#show"
    get "dashboard", to: "dashboard#show", as: :dashboard
    resources :bots, except: %i[show] do
      member { patch :rotate_token }
    end
    resources :subscriptions, only: %i[index update destroy]
    resources :allowlist, only: %i[index create destroy]
    resources :events, only: %i[index]
  end
end
