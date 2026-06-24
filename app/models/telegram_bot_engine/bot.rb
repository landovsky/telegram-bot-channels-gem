# frozen_string_literal: true

require "securerandom"

module TelegramBotEngine
  # A Telegram bot identity, persisted as data (docs/0001 §3.1). This is the gem's
  # next first-class entity beside Subscription/AllowedUser/Event: everything keyed
  # by a *Telegram bot identity* lives here; only source/channel routing keyed by an
  # *app source name* stays in the host app.
  class Bot < ActiveRecord::Base
    self.table_name = "telegram_bot_engine_bots"

    # `token` becomes encrypted at rest via ActiveRecord Encryption once the host app
    # provisions encryption keys (docs/0001 §6). Until keys are live it is seeded from
    # ENV as a plain column; the public API is identical either way. To enable:
    #   encrypts :token

    # Destroying a bot removes its own subscribers and allow-entries so they can't
    # leak: nullifying subscriptions would silently fold them into the default
    # audience, and nullifying allow-entries would escalate a per-bot allow to a
    # global one. Global entries (nil bot_id) belong to no bot and are untouched.
    has_many :subscriptions, class_name: "TelegramBotEngine::Subscription", dependent: :destroy
    has_many :allowed_users, class_name: "TelegramBotEngine::AllowedUser", dependent: :destroy

    scope :active, -> { where(active: true) }

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :token, presence: true
    validates :webhook_secret, presence: true, uniqueness: true
    # "exactly one row true" has two halves: at most one (demote_other_defaults) and
    # at least one. Without the second half an admin could uncheck "Default" on the
    # only default bot, leaving zero defaults — which makes every no-`bot:` broadcast/
    # notify call (the mandatory back-compat path) raise once Bot.default re-seeds onto
    # the still-present "default" slug. So refuse to clear the last default.
    validate :keep_at_least_one_default

    before_validation :ensure_webhook_secret, on: :create
    before_save :demote_other_defaults, if: -> { default? && will_save_change_to_default? }
    after_save :invalidate_client_cache
    after_destroy :invalidate_client_cache

    class << self
      # The default Bot — the back-compat anchor every no-`bot:` call site resolves to.
      # Seeds one on first use so the host's existing single-bot config keeps working.
      def default
        find_by(default: true) || ensure_default!
      end

      # A Bot by its stable slug handle (e.g. "default", "assistant").
      def resolve(slug)
        find_by!(slug: slug)
      end

      # Idempotently seed the default bot from the host's existing single-bot config/ENV
      # so nothing breaks on first boot (docs/0001 §4, §6). Safe to call repeatedly.
      def ensure_default!
        existing = find_by(default: true)
        return existing if existing

        create!(
          name: default_seed_name,
          slug: "default",
          token: default_seed_token,
          active: true,
          default: true
        )
      end

      private

      def default_seed_token
        ENV["TELEGRAM_BOT_TOKEN"].presence ||
          telegram_default_config[:token].presence ||
          raise(ArgumentError, "Cannot seed the default Bot: set ENV['TELEGRAM_BOT_TOKEN'] " \
                               "or configure telegram.bot in the host app before broadcasting.")
      end

      def default_seed_name
        telegram_default_config[:username].presence || "default"
      end

      def telegram_default_config
        (Telegram.bots_config[:default] || {}).to_h.symbolize_keys
      rescue StandardError
        {}
      end
    end

    # The memoized Telegram::Bot::Client for this bot's token, resolved via the registry.
    def client
      TelegramBotEngine.client_for(self)
    end

    private

    def ensure_webhook_secret
      self.webhook_secret = SecureRandom.hex(16) if webhook_secret.blank?
    end

    # "exactly one row true": promoting a bot to default demotes whoever held it.
    def demote_other_defaults
      self.class.where(default: true).where.not(id: id).update_all(default: false)
    end

    # Reject demoting the only default bot — promote another first (closes the UI hole
    # where unchecking "Default" then deleting would strand the back-compat anchor).
    def keep_at_least_one_default
      return if default?            # staying/becoming default is always fine
      return if new_record?         # creating a non-default bot is fine
      return unless default_changed? # an edit that doesn't touch `default` is fine
      return if self.class.where(default: true).where.not(id: id).exists?

      errors.add(:default, "can't be unset on the only default bot — promote another bot to default first")
    end

    def invalidate_client_cache
      TelegramBotEngine::Registry.invalidate(self)
    end
  end
end
