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

      # Text column. The snapshot column uses the JSON attribute caster below
      # instead of this coder. A second serialize pass would store a JSON
      # string inside a JSON document on MySQL.
      serialize :metadata, coder: JSON, type: Hash

      # MariaDB reports JSON columns as LONGTEXT. The text caster would write
      # a Ruby hash string and fail `json_valid`. Forcing the JSON caster
      # writes one JSON document on MySQL and on MariaDB.
      attribute :inbox_presentation_snapshot, :json

      # Definition-backed slot values. Same MariaDB JSON caster rationale as
      # the snapshot above. NULL for types without a MessageDefinition.
      attribute :slots, :json

      CONVERSATION_KEY_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\z/

      # Push collapse identity (Expo collapseId). Its own pattern and 64-char limit; it is never
      # derived from conversation_key, which is a thread identity with a different lifetime.
      COLLAPSE_KEY_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,63}\z/

      validates :notification_type_key, :title, :body, presence: true
      validates :execution_handoff_status, presence: true
      validates :collapse_key, format: { with: COLLAPSE_KEY_FORMAT }, allow_nil: true
      validate :conversation_identity_is_a_pair

      before_validation :normalize_conversation_identity

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

      # Reads the stored row only, never the registry: a type can lose its
      # definition after the row was written.
      def message_definition_backed?
        !metadata_version.nil?
      end

      def handoff_terminal?
        HANDOFF_TERMINAL_STATUSES.include?(execution_handoff_status)
      end

      def handoff_recoverable?
        HANDOFF_RECOVERABLE_STATUSES.include?(execution_handoff_status)
      end

      private

      def normalize_conversation_identity
        self.conversation_key = nil if conversation_key.blank?
        self.conversation_title = nil if conversation_title.blank?
        self.collapse_key = nil if collapse_key.blank?
      end

      def conversation_identity_is_a_pair
        if conversation_key.present? ^ conversation_title.present?
          errors.add(:conversation_key, "must be provided with a title")
          errors.add(:conversation_title, "must be provided with a key")
        end
        return if conversation_key.blank?
        return if conversation_key.match?(CONVERSATION_KEY_FORMAT)

        errors.add(:conversation_key, "is invalid")
      end
    end
  end
end
