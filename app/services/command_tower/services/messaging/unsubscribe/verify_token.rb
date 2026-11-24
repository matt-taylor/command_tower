# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Unsubscribe
        # Verifies a one-click unsubscribe token. Every failure (tampered, expired, wrong purpose,
        # malformed payload) is the same ValidationError with no detail, so a caller cannot tell them apart.
        class VerifyToken < CommandTower::Services::ApplicationService
          validate :token, is_a: String, required: true

          def call
            user_id, type_key = verified_payload
            return context.fail!(application_error: invalid_token_error) unless user_id && type_key

            context.user_id = user_id
            context.notification_type_key = type_key
          end

          private

          # @return [Array(Integer, String), nil] nil unless the payload is well formed
          def verified_payload
            signer = CommandTower::Messaging::Unsubscribe::TokenVerifier
            payload = signer.verifier.verified(token, purpose: signer::PURPOSE)
            return unless payload.is_a?(Hash)

            user_id = payload["u"]
            type_key = payload["t"]
            [user_id, type_key] if user_id.is_a?(Integer) && type_key.is_a?(String) && type_key.present?
          rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, JSON::ParserError
            nil
          end

          def invalid_token_error
            CommandTower::Errors::ValidationError.new(details: { token: "invalid" })
          end
        end
      end
    end
  end
end
