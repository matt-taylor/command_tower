# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushCapabilityUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "push_capability_unavailable"
        end

        def message
          "Push notifications are currently unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
