# frozen_string_literal: true

module CommandTower
  module Auth
    module EmailVerification
      class SendController < CommandTower::ApplicationController
        include CommandTower::Auth::AuthenticationBoundary
        include CommandTower::Auth::AuthorizationBoundary

        # Requesting a verification code is exactly the action an unverified user
        # needs, so the email verification precondition is bypassed here.
        before_action -> { authenticate_request!(bypass_email_validation: true) }
        before_action :authorize_request!

        def create
          result = CommandTower::Workflows::Auth::EmailVerification::SendWorkflow.call(
            current_user: current_user
          )
          render_application_result(result)
        end
      end
    end
  end
end
