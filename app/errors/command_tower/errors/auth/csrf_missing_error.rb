# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class CsrfMissingError < CommandTower::Errors::UnauthorizedError
        def code
          "csrf_missing"
        end

        def message
          "CSRF token missing"
        end
      end
    end
  end
end
