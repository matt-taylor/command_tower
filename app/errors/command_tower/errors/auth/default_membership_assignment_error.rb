# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class DefaultMembershipAssignmentError < CommandTower::Errors::ApplicationError
        def code
          "default_membership_assignment_failed"
        end

        def message
          "Default membership role could not be assigned"
        end
      end
    end
  end
end
