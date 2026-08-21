# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class ImpersonationSessionMissingError < CommandTower::Errors::ValidationError
        def initialize
          super(details: { impersonation: "not_active" })
        end

        def code
          "impersonation_session_missing"
        end

        def message
          "Impersonation is not active"
        end
      end
    end
  end
end
