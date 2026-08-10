# frozen_string_literal: true

module CommandTower
  module Messaging
    class NotificationPreference < CommandTower::ApplicationRecord
      self.table_name = "messaging_notification_preferences"

      belongs_to :user

      serialize :state, coder: JSON, type: Hash

      validates :notification_type_key, presence: true
      validates :state, presence: true
      validates :notification_type_key, uniqueness: { scope: :user_id }

      def self.find_for(recipient_id:, notification_type_key:)
        find_by(user_id: recipient_id, notification_type_key: notification_type_key.to_s)
      end
    end
  end
end
