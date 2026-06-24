# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

require "rspec/rails"
require "factory_bot"
require "database_cleaner/active_record"

# Load factory definitions from the gem's spec/factories directory
FactoryBot.definition_file_paths = [File.join(__dir__, "factories")]
FactoryBot.find_definitions

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  config.filter_run_when_matching :focus

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    # Run migrations in memory
    ActiveRecord::Schema.define do
      create_table :telegram_bot_engine_bots, force: true do |t|
        t.string  :name, null: false
        t.string  :slug, null: false
        t.string  :purpose
        t.string  :token, null: false
        t.string  :webhook_secret, null: false
        t.boolean :active, default: true
        t.boolean :default, default: false
        t.timestamps
      end

      add_index :telegram_bot_engine_bots, :slug, unique: true
      add_index :telegram_bot_engine_bots, :webhook_secret, unique: true
      add_index :telegram_bot_engine_bots, :active

      create_table :telegram_bot_engine_subscriptions, force: true do |t|
        t.bigint :bot_id
        t.bigint :chat_id, null: false
        t.bigint :user_id
        t.string :username
        t.string :first_name
        t.boolean :active, default: true
        t.json :metadata, default: {}
        t.timestamps
      end

      add_index :telegram_bot_engine_subscriptions, :chat_id
      add_index :telegram_bot_engine_subscriptions, :bot_id
      add_index :telegram_bot_engine_subscriptions, %i[bot_id chat_id], unique: true
      add_index :telegram_bot_engine_subscriptions, :chat_id, unique: true,
                where: "bot_id IS NULL", name: "index_tbe_subscriptions_on_chat_id_default_bot"
      add_index :telegram_bot_engine_subscriptions, :active
      add_index :telegram_bot_engine_subscriptions, :username

      create_table :telegram_bot_engine_allowed_users, force: true do |t|
        t.bigint :bot_id
        t.string :username, null: false
        t.string :note
        t.timestamps
      end

      add_index :telegram_bot_engine_allowed_users, :username
      add_index :telegram_bot_engine_allowed_users, :bot_id
      add_index :telegram_bot_engine_allowed_users, %i[bot_id username], unique: true
      add_index :telegram_bot_engine_allowed_users, :username, unique: true,
                where: "bot_id IS NULL", name: "index_tbe_allowed_users_on_username_global"

      create_table :telegram_bot_engine_events, force: true do |t|
        t.string :event_type, null: false
        t.string :action, null: false
        t.bigint :bot_id
        t.bigint :chat_id
        t.string :username
        t.json :details, default: {}
        t.datetime :created_at, null: false
      end

      add_index :telegram_bot_engine_events, :event_type
      add_index :telegram_bot_engine_events, :created_at
      add_index :telegram_bot_engine_events, :chat_id
      add_index :telegram_bot_engine_events, :bot_id
    end

    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:each) do
    TelegramBotEngine.reset_config!
    TelegramBotEngine::Registry.reset!
  end
end
