# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class InvalidCredentialsError < CommandTower::Errors::UnauthorizedError
        def code
          "invalid_credentials"
        end

        def message
          "Invalid credentials"
        end

        def log_level
          :info
        end
      end
    end
  end
end
