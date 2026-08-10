# frozen_string_literal: true

module CommandTower
  module Me
    module PhoneVerification
      class VerifyController < CommandTower::ApplicationController
        include CommandTower::Auth::AuthenticationBoundary
        include CommandTower::Auth::AuthorizationBoundary

        before_action :authenticate_request!
        before_action :authorize_request!

        def create
          deserialized = CommandTower::Deserializers::Me::PhoneVerification::VerifyDeserializer.call(params)
          unless deserialized.success?
            return render_application_result(
              CommandTower::Workflows::WorkflowResult.failure(
                errors: [CommandTower::Errors::Account::PhoneVerificationCodeInvalidError.new],
                http_status: :unprocessable_entity
              )
            )
          end

          result = CommandTower::Workflows::Me::PhoneVerification::VerifyWorkflow.call(
            current_user: current_user,
            code: deserialized.input.code,
            auth_context: current_auth_context
          )
          render_application_result(result)
        end
      end
    end
  end
end
