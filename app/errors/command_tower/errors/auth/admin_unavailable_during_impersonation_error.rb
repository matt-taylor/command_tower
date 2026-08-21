# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class AdminUnavailableDuringImpersonationError < CommandTower::Errors::ApplicationError
        def code
          "admin_unavailable_during_impersonation"
        end

        def message
          "Admin tools are unavailable while impersonating a user."
        end
      end
    end
  end
end
