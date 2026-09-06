# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class PushEndpointNotFoundError < CommandTower::Errors::ApplicationError
        def code
          "push_endpoint_not_found"
        end

        def message
          "Push endpoint was not found"
        end

        def log_level
          :info
        end
      end
    end
  end
end
