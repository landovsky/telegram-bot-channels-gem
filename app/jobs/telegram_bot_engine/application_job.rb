# frozen_string_literal: true

module TelegramBotEngine
  # Engine-local base job so DeliveryJob doesn't depend on the host app defining a
  # top-level ::ApplicationJob — an API-only or non-standard host may not have one,
  # which would otherwise raise NameError when the job is loaded. Inheriting
  # ActiveJob::Base directly keeps the engine self-contained.
  class ApplicationJob < ActiveJob::Base
  end
end
