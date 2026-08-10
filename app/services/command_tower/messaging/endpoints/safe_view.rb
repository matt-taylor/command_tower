# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      SafeView = Data.define(
        :id,
        :owner_user_id,
        :channel_key,
        :lifecycle_state,
        :verification_state,
        :masked_display_value,
        :credentials_configured,
        :encryption_key_version,
        :verified_at,
        :revoked_at,
        :last_successful_use_at,
        :created_at,
        :updated_at,
      ) do
        def self.from_record(record)
          new(
            id: record.id,
            owner_user_id: record.user_id,
            channel_key: record.channel_key,
            lifecycle_state: record.lifecycle_state,
            verification_state: record.verification_state,
            masked_display_value: record.masked_display_value,
            credentials_configured: credentials_configured?(record),
            encryption_key_version: record.encryption_key_version,
            verified_at: record.verified_at,
            revoked_at: record.revoked_at,
            last_successful_use_at: record.last_successful_use_at,
            created_at: record.created_at,
            updated_at: record.updated_at,
          ).freeze
        end

        def self.credentials_configured?(record)
          if record.typed_credentials_channel?
            record.pushover_credential.present?
          else
            record.address_ciphertext.present?
          end
        end
        private_class_method :credentials_configured?
      end
    end
  end
end
