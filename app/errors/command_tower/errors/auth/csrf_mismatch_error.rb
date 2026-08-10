# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class CsrfMismatchError < CommandTower::Errors::UnauthorizedError
        def code
          "csrf_mismatch"
        end

        def message
          "CSRF token mismatch"
        end
      end
    end
  end
end
