# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Pushover
        # Single verification authority for Pushover endpoints.
        # begin → decrypt → validate.json → test messages.json → mark_verified | mark_verification_failed
        class Verify
          def self.call(owner_user_id:, endpoint_id:)
            new(owner_user_id:, endpoint_id:).call
          end

          def initialize(owner_user_id:, endpoint_id:)
            @owner_user_id = owner_user_id
            @endpoint_id = endpoint_id
          end

          def call
            record = load_active_pushover!
            assert_adapter_enabled!

            begin_verification_lifecycle!(record)
            credentials = SecretReader.read_pushover_credentials!(
              owner_user_id: @owner_user_id,
              endpoint_id: @endpoint_id,
            )

            validate_result = Messaging::Pushover::Transport.validate_user!(
              user_key: credentials.fetch(:user_key),
              application_token: credentials.fetch(:application_token),
            )
            unless validate_result.success?
              raise_after_failed!(validate_result)
            end

            config = CommandTower.config.messaging.pushover
            test_result = Messaging::Pushover::Transport.send_test_notification!(
              user_key: credentials.fetch(:user_key),
              application_token: credentials.fetch(:application_token),
              title: config.test_title,
              message: config.test_message,
            )
            unless test_result.success?
              raise_after_failed!(test_result)
            end

            MarkVerified.call(owner_user_id: @owner_user_id, endpoint_id: @endpoint_id)
          end

          private

          def load_active_pushover!
            record = Endpoint.for_owner(@owner_user_id).find_by(id: @endpoint_id)
            raise NotFoundError, "endpoint not found" if record.nil?

            ChannelGate.assert_record_supported!(record)
            unless record.channel_key == "pushover"
              raise ValidationError, "endpoint is not a pushover endpoint"
            end
            unless record.active?
              raise ValidationError, "endpoint must be active to verify"
            end
            if record.pushover_credential.nil?
              raise ValidationError, "pushover credentials are missing"
            end

            record
          end

          def assert_adapter_enabled!
            adapter = CommandTower.config.messaging.pushover.adapter.to_s
            return unless adapter == "disabled" || adapter.blank?

            raise ValidationError, "Pushover verification adapter is disabled"
          end

          def begin_verification_lifecycle!(record)
            case record.verification_state
            when "pending"
              nil
            when "verified"
              ResetVerification.call(owner_user_id: @owner_user_id, endpoint_id: @endpoint_id)
              BeginVerification.call(owner_user_id: @owner_user_id, endpoint_id: @endpoint_id)
            else
              BeginVerification.call(owner_user_id: @owner_user_id, endpoint_id: @endpoint_id)
            end
          end

          def raise_after_failed!(result)
            MarkVerificationFailed.call(owner_user_id: @owner_user_id, endpoint_id: @endpoint_id)
            raise VerificationFailedError.new(
              error_code: result.error_code || :verification_failed,
              message: result.error_message.presence || "Pushover verification failed",
            )
          end
        end
      end
    end
  end
end
