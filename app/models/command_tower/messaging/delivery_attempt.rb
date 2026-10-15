# frozen_string_literal: true

module CommandTower
  module Messaging
    class DeliveryAttempt < CommandTower::ApplicationRecord
      self.table_name = "messaging_delivery_attempts"

      STATUS_STARTED = "started"
      STATUS_SUCCEEDED = "succeeded"
      STATUS_FAILED_RETRYABLE = "failed_retryable"
      STATUS_FAILED_TERMINAL = "failed_terminal"

      STATUSES = [
        STATUS_STARTED,
        STATUS_SUCCEEDED,
        STATUS_FAILED_RETRYABLE,
        STATUS_FAILED_TERMINAL,
      ].freeze

      belongs_to :channel_delivery,
                 class_name: "CommandTower::Messaging::ChannelDelivery",
                 inverse_of: :delivery_attempts

      # MariaDB reports JSON columns as LONGTEXT. The text caster would write
      # a Ruby hash string and fail `json_valid`. Forcing the JSON caster
      # writes one JSON document on MySQL and on MariaDB.
      attribute :provider_metadata, :json

      validates :status, presence: true, inclusion: { in: STATUSES }
      validates :started_at, presence: true
    end
  end
end
