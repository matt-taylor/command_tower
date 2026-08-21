# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class SelfImpersonationError < CommandTower::Errors::ValidationError
        def initialize
          super(details: { target: "cannot_impersonate_self" })
        end

        def code
          "self_impersonation_forbidden"
        end

        def message
          "Cannot impersonate yourself"
        end
      end
    end
  end
end
