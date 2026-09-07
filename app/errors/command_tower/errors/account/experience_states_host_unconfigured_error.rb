# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class ExperienceStatesHostUnconfiguredError < CommandTower::Errors::ApplicationError
        def code
          "experience_states_host_unconfigured"
        end

        def message
          "Experience states are currently unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
