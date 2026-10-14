# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushTestDestinationError < CommandTower::Errors::ApplicationError
        def code
          "push_test_destination_unresolved"
        end

        def message
          "Push test destination is not configured"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
