# frozen_string_literal: true

module CommandTower
  module Messaging
    class Communication < CommandTower::ApplicationRecord
      self.table_name = "messaging_communications"

      STATUS_ACCEPTED = "accepted"

      HANDOFF_PENDING = "pending"
      HANDOFF_ENQUEUED = "enqueued"
      HANDOFF_COMPLETE = "complete"
      HANDOFF_FAILED = "failed"

      HANDOFF_TERMINAL_STATUSES = [HANDOFF_ENQUEUED, HANDOFF_COMPLETE].freeze
      HANDOFF_RECOVERABLE_STATUSES = [HANDOFF_PENDING, HANDOFF_FAILED].freeze

      belongs_to :user

      has_one :destination_plan,
              class_name: "CommandTower::Messaging::DestinationPlan",
              dependent: :destroy,
              inverse_of: :communication
      has_one :inbox_item,
              class_name: "CommandTower::Messaging::InboxItem",
              dependent: :destroy,
              inverse_of: :communication
      has_many :channel_deliveries,
               class_name: "CommandTower::Messaging::ChannelDelivery",
               dependent: :destroy,
               inverse_of: :communication

      serialize :metadata, coder: JSON, type: Hash

      validates :notification_type_key, :title, :body, presence: true
      validates :execution_handoff_status, presence: true

      scope :needing_handoff_recovery, lambda { |grace_before:|
        where(status: STATUS_ACCEPTED, execution_handoff_status: HANDOFF_RECOVERABLE_STATUSES)
          .where(arel_table[:updated_at].lt(grace_before))
      }

      def self.find_by_idempotency_namespace(user_id:, notification_type_key:, host_event_identity:)
        find_by(
          user_id:,
          notification_type_key: notification_type_key.to_s,
          host_event_identity: host_event_identity.to_s,
        )
      end

      def handoff_terminal?
        HANDOFF_TERMINAL_STATUSES.include?(execution_handoff_status)
      end

      def handoff_recoverable?
        HANDOFF_RECOVERABLE_STATUSES.include?(execution_handoff_status)
      end
    end
  end
end
