# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushTestNoEndpointError < CommandTower::Errors::ApplicationError
        def code
          "push_test_no_endpoint"
        end

        def message
          "No active push endpoint is registered for this account"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
