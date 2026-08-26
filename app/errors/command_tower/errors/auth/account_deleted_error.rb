# frozen_string_literal: true

module CommandTower
  module Errors
    module Auth
      class AccountDeletedError < CommandTower::Errors::UnauthorizedError
        def code
          "account_deleted"
        end

        def message
          "Account has been deleted"
        end

        def log_level
          :info
        end
      end
    end
  end
end
