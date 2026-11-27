# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      # Destructive inbox actions are refused while impersonating: the operator must not delete
      # the impersonated user's messages.
      class InboxImpersonationForbiddenError < CommandTower::Errors::ApplicationError
        def code
          "inbox_impersonation_forbidden"
        end

        def message
          "This inbox action is unavailable while impersonating a user."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
