# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module PhoneVerification
        class SendWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, auth_context: nil)
            unless CommandTower::Services::Me::SmsProductGate.enabled?
              error = CommandTower::Errors::Account::SmsCapabilityUnavailableError.new
              return failure(
                errors: [error],
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
              )
            end

            send_result = CommandTower::Services::Account::PhoneVerification::Send.call(user: current_user)

            unless send_result.success?
              error = send_result.errors.first
              return failure(
                errors: send_result.errors,
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error),
                meta: throttle_meta(error) || {}
              )
            end

            data = send_result.data
            success(
              payload: {
                codeLength: data[:code_length],
                expiresAt: iso(data[:expires_at]),
                resendAvailableAt: iso(data[:resend_available_at]),
                phoneNumber: data[:phone_number]
              }.compact,
              http_status: :ok,
              response_effects: expire_header_effects(auth_context)
            )
          end

          private

          def iso(value)
            value.respond_to?(:iso8601) ? value.iso8601 : value
          end

          def throttle_meta(error)
            return unless error.is_a?(CommandTower::Errors::Account::PhoneVerificationThrottledError)
            return if error.resend_available_at.blank?

            { resendAvailableAt: iso(error.resend_available_at) }
          end

          def expire_header_effects(auth_context)
            return if auth_context.nil?

            { set_expire_header: auth_context.token_expires_at }
          end
        end
      end
    end
  end
end
