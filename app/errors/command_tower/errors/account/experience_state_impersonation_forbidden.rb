# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class ExperienceStateImpersonationForbidden < CommandTower::Errors::ForbiddenError
        def code
          "experience_state_impersonation_forbidden"
        end

        def message
          "Experience states cannot be changed while impersonating"
        end
      end
    end
  end
end
