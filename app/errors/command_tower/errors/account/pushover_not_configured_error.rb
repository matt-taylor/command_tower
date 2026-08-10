# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushoverNotConfiguredError < CommandTower::Errors::ApplicationError
        def code
          "pushover_not_configured"
        end

        def message
          "Pushover is not configured"
        end

        def log_level
          :info
        end
      end
    end
  end
end
