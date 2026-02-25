# frozen_string_literal: true

Rails.application.routes.draw do
  mount TelegramBotEngine::Engine, at: "/telegram/admin"
end
