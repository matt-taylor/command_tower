# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class NestedImpersonationError < CommandTower::Errors::ForbiddenError
        def code
          "nested_impersonation_forbidden"
        end

        def message
          "Nested impersonation is forbidden"
        end
      end
    end
  end
end
