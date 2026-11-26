# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      # The device session was signed out, replaced, or no longer exists.
      class SessionRevokedError < CommandTower::Errors::UnauthorizedError
        def code
          "session_revoked"
        end

        def message
          "Your session has ended. Please sign in again."
        end
      end
    end
  end
end
