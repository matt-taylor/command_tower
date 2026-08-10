# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class EmailAvailabilityWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(input:, signup_session:)
          rate_result = CommandTower::Services::Auth::SignupRateLimits::CheckAvailability.call(
            signup_session: signup_session,
            kind: :email
          )
          unless rate_result.success?
            return failure(
              errors: rate_result.errors,
              http_status: SignupErrorStatus.http_status_for(rate_result.errors.first)
            )
          end

          availability_result = CommandTower::Services::Auth::EmailAvailability.call(email: input.email)
          unless availability_result.success?
            return failure(errors: availability_result.errors, http_status: :internal_server_error)
          end

          data = availability_result.data
          success(
            payload: CommandTower::Serializers::Auth::EmailAvailabilitySerializer.serialize(
              valid: data[:valid],
              available: data[:available],
              message: data[:message]
            ),
            http_status: :ok
          )
        end
      end
    end
  end
end
