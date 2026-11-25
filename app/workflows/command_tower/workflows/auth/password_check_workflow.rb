# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # Live password-policy feedback for signup, reset and change-password screens.
      # The password is evaluated in memory only: never stored, logged or echoed.
      class PasswordCheckWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(input:, client_ip:)
          rate_result = CommandTower::Services::Auth::PasswordPolicy::CheckRateLimit.call(client_ip: client_ip.to_s)
          return failure(errors: rate_result.errors, http_status: :too_many_requests) unless rate_result.success?

          check = CommandTower::Services::Auth::PasswordPolicy::Check.call(password: input.password)
          return failure(errors: check.errors, http_status: :internal_server_error) unless check.success?

          success(payload: serialize(check.data), http_status: :ok)
        end

        private

        def serialize(data)
          policy = CommandTower::Services::Auth::PasswordPolicy::Check
          CommandTower::Serializers::Auth::PasswordCheckSerializer.serialize(
            valid: data[:valid],
            failures: data[:failures],
            message: data[:valid] ? nil : policy.message_for(data[:failures])
          )
        end
      end
    end
  end
end
