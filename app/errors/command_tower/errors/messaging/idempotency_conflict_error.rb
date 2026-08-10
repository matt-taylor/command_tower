# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      class IdempotencyConflictError < CommandTower::Errors::ApplicationError
        def code
          "messaging_idempotency_conflict"
        end

        def message
          "Messaging accept conflicts with an existing host event"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
