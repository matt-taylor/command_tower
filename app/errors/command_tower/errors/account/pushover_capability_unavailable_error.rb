# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushoverCapabilityUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "pushover_capability_unavailable"
        end

        def message
          "Pushover is currently unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
