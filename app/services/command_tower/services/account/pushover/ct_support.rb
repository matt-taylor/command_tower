# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Pushover
        # Shared CT Endpoints helpers for Account Pushover capability services.
        module CtSupport
          module_function

          def active_endpoint(user)
            views = CommandTower::Messaging::Endpoints.list(
              owner_user_id: user.id,
              channel_key: "pushover"
            )
            views.find { |view| view.lifecycle_state.to_s == "active" }
          end

          def map_ct_exception!(error)
            case error
            when CommandTower::Messaging::Endpoints::VerificationFailedError
              map_verification_failed!(error)
            when CommandTower::Messaging::Endpoints::ConflictError
              CommandTower::Errors::Account::PushoverAlreadyConfiguredError.new
            when CommandTower::Messaging::Endpoints::NotFoundError
              CommandTower::Errors::Account::PushoverNotConfiguredError.new
            when CommandTower::Messaging::Endpoints::ValidationError
              if error.message.to_s.include?("disabled")
                CommandTower::Errors::Account::PushoverCapabilityUnavailableError.new
              else
                CommandTower::Errors::ValidationError.new(details: { base: "Invalid Pushover credentials" })
              end
            else
              CommandTower::Errors::InternalError.new
            end
          end

          def map_verification_failed!(error)
            case error.error_code
            when :invalid_user
              CommandTower::Errors::Account::PushoverVerificationFailedError.new(
                code: "pushover_invalid_user",
                message: "Pushover user key is invalid"
              )
            when :invalid_token
              CommandTower::Errors::Account::PushoverVerificationFailedError.new(
                code: "pushover_invalid_token",
                message: "Pushover application token is invalid"
              )
            when :invalid_credentials
              CommandTower::Errors::Account::PushoverVerificationFailedError.new(
                code: "pushover_invalid_credentials",
                message: "Pushover credentials were rejected"
              )
            when :timeout
              CommandTower::Errors::Account::PushoverVerificationFailedError.new(
                code: "pushover_provider_timeout",
                message: "Pushover provider timed out"
              )
            when :provider_unavailable
              CommandTower::Errors::Account::PushoverProviderUnavailableError.new
            else
              CommandTower::Errors::Account::PushoverVerificationFailedError.new
            end
          end
        end
      end
    end
  end
end
