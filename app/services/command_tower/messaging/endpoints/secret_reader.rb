# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      # Internal decrypt-at-use. Not part of the safe public façade.
      class SecretReader
        def self.read!(owner_user_id:, endpoint_id:)
          new(owner_user_id:, endpoint_id:).read!
        end

        def self.read_pushover_credentials!(owner_user_id:, endpoint_id:)
          new(owner_user_id:, endpoint_id:).read_pushover_credentials!
        end

        def initialize(owner_user_id:, endpoint_id:)
          @owner_user_id = owner_user_id
          @endpoint_id = endpoint_id
        end

        def read!
          record = load_supported_record!
          if record.typed_credentials_channel?
            raise ValidationError, "use read_pushover_credentials! for pushover endpoints"
          end
          if record.address_ciphertext.blank?
            raise ValidationError, "endpoint has no address ciphertext"
          end

          SecretBox.decrypt(
            record.address_ciphertext,
            key_version: record.encryption_key_version,
          )
        end

        def read_pushover_credentials!
          record = load_supported_record!
          unless record.channel_key == "pushover"
            raise ValidationError, "endpoint is not a pushover endpoint"
          end

          credential = record.pushover_credential
          raise ValidationError, "pushover credentials are missing" if credential.nil?

          key_version = credential.encryption_key_version
          {
            user_key: SecretBox.decrypt(
              credential.user_key_ciphertext,
              key_version:,
              purpose: SecretBox::PUSHOVER_USER_KEY_PURPOSE,
            ),
            application_token: SecretBox.decrypt(
              credential.application_token_ciphertext,
              key_version:,
              purpose: SecretBox::PUSHOVER_APPLICATION_TOKEN_PURPOSE,
            ),
          }
        end

        private

        def load_supported_record!
          record = Endpoint.for_owner(@owner_user_id).find_by(id: @endpoint_id)
          raise NotFoundError, "endpoint not found" if record.nil?

          ChannelGate.assert_record_supported!(record)
          record
        end
      end
    end
  end
end
