# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushoverAlreadyConfiguredError < CommandTower::Errors::ApplicationError
        def code
          "pushover_already_configured"
        end

        def message
          "Pushover is already configured"
        end

        def log_level
          :info
        end
      end
    end
  end
end
