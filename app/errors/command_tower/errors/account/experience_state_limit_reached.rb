# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class ExperienceStateLimitReached < CommandTower::Errors::ApplicationError
        def code
          "experience_state_limit_reached"
        end

        def message
          "Experience state limit reached"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
