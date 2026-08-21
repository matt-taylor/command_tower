# frozen_string_literal: true

module CommandTower
  module Impersonation
    class Session < CommandTower::ApplicationRecord
      self.table_name = "command_tower_impersonation_sessions"

      END_REASONS = %w[manual idle_timeout absolute_timeout logout revoked].freeze

      belongs_to :actor, class_name: "User", foreign_key: :actor_user_id
      belongs_to :target, class_name: "User", foreign_key: :target_user_id

      before_create :assign_public_id

      validates :actor_user_id, :target_user_id, :started_at, :last_activity_at,
        :absolute_expires_at, :idle_expires_at, presence: true
      validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

      scope :open, -> { where(ended_at: nil) }

      def open?
        ended_at.nil?
      end

      def idle_expired?(at: Time.current)
        idle_expires_at <= at
      end

      def absolutely_expired?(at: Time.current)
        absolute_expires_at <= at
      end

      def expired?(at: Time.current)
        idle_expired?(at:) || absolutely_expired?(at:)
      end

      def expiration_reason(at: Time.current)
        return "absolute_timeout" if absolutely_expired?(at:)
        return "idle_timeout" if idle_expired?(at:)

        nil
      end

      private

      def assign_public_id
        self.id = SecureRandom.uuid if id.blank?
      end
    end
  end
end
