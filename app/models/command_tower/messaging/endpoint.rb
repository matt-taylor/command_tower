# frozen_string_literal: true

module CommandTower
  module Messaging
    class Endpoint < CommandTower::ApplicationRecord
      self.table_name = "messaging_endpoints"

      SINGLE_ACTIVE_CHANNELS = %w[pushover].freeze
      LIFECYCLE_STATES = %w[active revoked invalid retired].freeze
      VERIFICATION_STATES = %w[unverified pending verified failed].freeze
      TERMINAL_LIFECYCLES = %w[revoked invalid retired].freeze

      TYPED_CREDENTIAL_CHANNELS = %w[pushover].freeze

      belongs_to :user
      has_one :pushover_credential,
              class_name: "CommandTower::Messaging::EndpointPushoverCredential",
              foreign_key: :messaging_endpoint_id,
              dependent: :destroy,
              inverse_of: :endpoint

      validates :channel_key, presence: true
      validates :lifecycle_state, inclusion: { in: LIFECYCLE_STATES }
      validates :verification_state, inclusion: { in: VERIFICATION_STATES }
      validates :address_fingerprint, presence: true
      validates :masked_display_value, presence: true
      validates :address_ciphertext, presence: true, unless: :typed_credentials_channel?
      validates :address_ciphertext, absence: true, if: :typed_credentials_channel?
      validates :encryption_key_version, presence: true
      validate :channel_must_support_endpoint_records
      validate :timestamps_consistent_with_state

      before_validation :derive_uniqueness_columns!

      scope :for_owner, ->(owner_user_id) { where(user_id: owner_user_id) }
      scope :active, -> { where(lifecycle_state: "active") }
      scope :for_channel, ->(channel_key) { where(channel_key: channel_key.to_s) }

      def self.single_active_channel?(channel_key)
        SINGLE_ACTIVE_CHANNELS.include?(channel_key.to_s)
      end

      def self.typed_credentials_channel?(channel_key)
        TYPED_CREDENTIAL_CHANNELS.include?(channel_key.to_s)
      end

      def typed_credentials_channel?
        self.class.typed_credentials_channel?(channel_key)
      end

      def active?
        lifecycle_state == "active"
      end

      def terminal?
        TERMINAL_LIFECYCLES.include?(lifecycle_state)
      end

      # Centralized uniqueness derivation — must run whenever lifecycle, owner,
      # channel, or fingerprint change. Terminal rows clear both slots.
      def derive_uniqueness_columns!
        if active?
          self.active_fingerprint = address_fingerprint
          self.single_active_slot =
            if self.class.single_active_channel?(channel_key)
              "#{user_id}:#{channel_key}"
            end
        else
          self.active_fingerprint = nil
          self.single_active_slot = nil
        end
      end

      private

      def channel_must_support_endpoint_records
        return if channel_key.blank?

        definition = Channels.fetch(channel_key)
        if definition.nil? || !definition.supports_endpoint_records
          errors.add(:channel_key, "must be a catalog channel that supports endpoint records")
        end
      end

      def timestamps_consistent_with_state
        if verification_state == "verified" && verified_at.nil?
          errors.add(:verified_at, "must be set when verification_state is verified")
        end
        if verification_state != "verified" && verified_at.present? && verification_state_changed?
          # reset_verification clears verified_at; allow historical verified_at only when verified
        end
        if %w[revoked].include?(lifecycle_state) && revoked_at.nil?
          errors.add(:revoked_at, "must be set when lifecycle_state is revoked")
        end
      end
    end
  end
end
