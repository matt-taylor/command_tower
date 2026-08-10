# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushoverProviderUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "pushover_provider_unavailable"
        end

        def message
          "Pushover provider is temporarily unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
