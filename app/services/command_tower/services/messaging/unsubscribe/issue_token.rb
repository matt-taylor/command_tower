# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Unsubscribe
        # Signs a one-click unsubscribe token for one user and one notification type. The payload is
        # `{ u: user_id, t: notification_type_key }`; it expires after 90 days.
        class IssueToken < CommandTower::Services::ApplicationService
          validate :user_id, is_a: Integer, required: true
          validate :notification_type_key, is_a: String, required: true

          def call
            signer = CommandTower::Messaging::Unsubscribe::TokenVerifier
            context.token = signer.verifier.generate(
              { u: user_id, t: notification_type_key },
              purpose: signer::PURPOSE,
              expires_in: signer::EXPIRES_IN
            )
          end
        end
      end
    end
  end
end
