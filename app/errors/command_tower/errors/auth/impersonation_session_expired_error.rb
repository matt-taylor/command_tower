# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class ImpersonationSessionExpiredError < CommandTower::Errors::UnauthorizedError
        def code
          "impersonation_session_expired"
        end

        def message
          "Impersonation session is no longer valid"
        end
      end
    end
  end
end
