# frozen_string_literal: true

module CommandTower
  module Messaging
    # Safe owner-facing Endpoint Platform façade.
    # Decrypt-at-use lives on Endpoints::SecretReader (internal).
    module Endpoints
      module_function

      def create(owner_user_id:, channel_key:, address: nil, credentials: nil)
        Create.call(owner_user_id:, channel_key:, address:, credentials:)
      end

      def replace(owner_user_id:, channel_key: nil, endpoint_id: nil, address: nil, credentials: nil)
        Replace.call(owner_user_id:, channel_key:, endpoint_id:, address:, credentials:)
      end

      def revoke(owner_user_id:, endpoint_id:)
        Revoke.call(owner_user_id:, endpoint_id:)
      end

      def list(owner_user_id:, channel_key: nil)
        Query.list(owner_user_id:, channel_key:)
      end

      def show(owner_user_id:, endpoint_id:)
        Query.show(owner_user_id:, endpoint_id:)
      end

      def mark_invalid(owner_user_id:, endpoint_id:)
        MarkInvalid.call(owner_user_id:, endpoint_id:)
      end

      def begin_verification(owner_user_id:, endpoint_id:)
        BeginVerification.call(owner_user_id:, endpoint_id:)
      end

      def mark_verified(owner_user_id:, endpoint_id:)
        MarkVerified.call(owner_user_id:, endpoint_id:)
      end

      def mark_verification_failed(owner_user_id:, endpoint_id:)
        MarkVerificationFailed.call(owner_user_id:, endpoint_id:)
      end

      def reset_verification(owner_user_id:, endpoint_id:)
        ResetVerification.call(owner_user_id:, endpoint_id:)
      end

      def verify_pushover!(owner_user_id:, endpoint_id:)
        Pushover::Verify.call(owner_user_id:, endpoint_id:)
      end
    end
  end
end
