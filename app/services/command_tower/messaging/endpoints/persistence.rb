# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Persistence
        module_function

        MAX_RETRIES = 3

        def with_unique_conflict_handling
          attempts = 0
          begin
            attempts += 1
            yield
          rescue ActiveRecord::RecordNotUnique => e
            translated = translate_unique_conflict(e)
            raise translated if translated

            raise ConflictError, "endpoint uniqueness conflict" if attempts >= MAX_RETRIES

            retry
          end
        end

        def translate_unique_conflict(error)
          message = error.message.to_s
          if message.include?("index_messaging_endpoints_active_fingerprint") ||
              message.include?("active_fingerprint")
            :duplicate_fingerprint
          elsif message.include?("index_messaging_endpoints_single_active_slot") ||
              message.include?("single_active_slot")
            ConflictError.new("an active endpoint already exists for this owner and channel; use replace")
          else
            ConflictError.new("endpoint uniqueness conflict")
          end
        end
        private_class_method :translate_unique_conflict

        def find_active_by_fingerprint(owner_user_id:, channel_key:, fingerprint:)
          Endpoint.active.for_owner(owner_user_id).for_channel(channel_key).find_by(
            address_fingerprint: fingerprint,
          )
        end

        def build_encrypted_attrs(normalized_address:, masked_display_value:)
          encrypted = SecretBox.encrypt(normalized_address)
          {
            address_fingerprint: Fingerprinter.fingerprint(normalized_address),
            masked_display_value:,
            address_ciphertext: encrypted.fetch(:ciphertext),
            encryption_key_version: encrypted.fetch(:key_version),
          }
        end

        def build_pushover_parent_attrs(validated:)
          {
            address_fingerprint: Fingerprinter.fingerprint(validated.pair_fingerprint_material),
            masked_display_value: validated.masked_display_value,
            address_ciphertext: nil,
            encryption_key_version: SecretBox.key_version,
          }
        end

        def build_pushover_credential_attrs(validated:)
          user_key = SecretBox.encrypt(
            validated.normalized_user_key,
            purpose: SecretBox::PUSHOVER_USER_KEY_PURPOSE,
          )
          application_token = SecretBox.encrypt(
            validated.normalized_application_token,
            purpose: SecretBox::PUSHOVER_APPLICATION_TOKEN_PURPOSE,
          )

          {
            user_key_ciphertext: user_key.fetch(:ciphertext),
            application_token_ciphertext: application_token.fetch(:ciphertext),
            encryption_key_version: user_key.fetch(:key_version),
          }
        end

        def create_pushover_credential!(endpoint:, validated:)
          ::CommandTower::Messaging::EndpointPushoverCredential.create!(
            endpoint:,
            **build_pushover_credential_attrs(validated:),
          )
        end
      end
    end
  end
end
