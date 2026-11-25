# frozen_string_literal: true

module CommandTower
  module Auth
    # One signed-in device. `public_id` is carried in the JWT as `sid`.
    class DeviceSession < CommandTower::ApplicationRecord
      self.table_name = "command_tower_device_sessions"

      REVOKED_REASONS = %w[logout password_reset password_change admin_mutation tombstone replaced].freeze

      belongs_to :user

      before_validation :assign_public_id, on: :create

      validates :public_id, :last_seen_at, :absolute_expires_at, presence: true
      validates :public_id, uniqueness: true
      validates :revoked_reason, inclusion: { in: REVOKED_REASONS }, allow_nil: true

      scope :active, -> { where(revoked_at: nil) }

      def revoked?
        revoked_at.present?
      end

      private

      def assign_public_id
        self.public_id = SecureRandom.uuid if public_id.blank?
      end
    end
  end
end
