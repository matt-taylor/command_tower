# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      # The device session passed its idle or absolute timeout.
      class SessionExpiredError < CommandTower::Errors::UnauthorizedError
        def code
          "session_expired"
        end

        def message
          "Your session has expired. Please sign in again."
        end
      end
    end
  end
end
