# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class EmailVerificationRequiredError < CommandTower::Errors::UnauthorizedError
        def code
          "email_verification_required"
        end

        def message
          "Email verification required"
        end

        def log_level
          :info
        end
      end
    end
  end
end
