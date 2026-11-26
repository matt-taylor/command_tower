# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class ExperienceStateUnregistered < CommandTower::Errors::ApplicationError
        def code
          "experience_state_unregistered"
        end

        def message
          "Experience state is not registered"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
