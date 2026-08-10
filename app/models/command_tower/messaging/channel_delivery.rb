# frozen_string_literal: true

module CommandTower
  module Messaging
    class ChannelDelivery < CommandTower::ApplicationRecord
      self.table_name = "messaging_channel_deliveries"

      STATUS_PLANNED = "planned"
      STATUS_QUEUED = "queued"
      STATUS_EXECUTING = "executing"
      STATUS_ACCEPTED_BY_PROVIDER = "accepted_by_provider"
      STATUS_FAILED_RETRYABLE = "failed_retryable"
      STATUS_FAILED_TERMINAL = "failed_terminal"

      EXECUTION_TERMINAL_STATUSES = [
        STATUS_ACCEPTED_BY_PROVIDER,
        STATUS_FAILED_TERMINAL,
      ].freeze

      belongs_to :communication,
                 class_name: "CommandTower::Messaging::Communication",
                 inverse_of: :channel_deliveries

      has_many :delivery_attempts,
               class_name: "CommandTower::Messaging::DeliveryAttempt",
               dependent: :destroy,
               inverse_of: :channel_delivery

      validates :channel_key, presence: true
      validates :channel_key, uniqueness: { scope: :communication_id }

      scope :queued_for_execution, -> { where(status: STATUS_QUEUED) }
      scope :failed_retryable, -> { where(status: STATUS_FAILED_RETRYABLE) }
      scope :executing, -> { where(status: STATUS_EXECUTING) }

      def execution_terminal?
        EXECUTION_TERMINAL_STATUSES.include?(status)
      end

      def execution_claimable?
        status == STATUS_QUEUED
      end
    end
  end
end
