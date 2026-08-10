# frozen_string_literal: true

module CommandTower
  module Auth
    module EmailVerification
      class VerifyController < CommandTower::ApplicationController
        include CommandTower::Auth::AuthenticationBoundary
        include CommandTower::Auth::AuthorizationBoundary

        before_action -> { authenticate_request!(bypass_email_validation: true) }
        before_action :authorize_request!

        def create
          deserialized = CommandTower::Deserializers::Auth::EmailVerification::VerifyDeserializer.call(params)
          return render_verify_deserializer_errors unless deserialized.success?

          result = CommandTower::Workflows::Auth::EmailVerification::VerifyWorkflow.call(
            current_user: current_user,
            input: deserialized.input
          )
          render_application_result(result)
        end

        private

        def render_verify_deserializer_errors
          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [
                CommandTower::Errors::Auth::VerificationCodeInvalidError.new(
                  details: { code: "Verification code is required" }
                )
              ],
              http_status: :unprocessable_entity
            )
          )
        end
      end
    end
  end
end
