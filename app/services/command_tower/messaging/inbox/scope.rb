# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # Recipient-scoped InboxItem relation — never load globally then check ownership.
      module Scope
        module_function

        def for_recipient(recipient_id)
          Messaging::InboxItem
            .joins(:communication)
            .where(messaging_communications: { user_id: recipient_id })
        end

        def find_for_recipient(recipient_id:, inbox_item_id:, lock: false)
          relation = for_recipient(recipient_id)
          relation = relation.lock if lock
          relation.find_by(id: inbox_item_id)
        end

        # An inbox item is 1:1 with its communication; nil when the communication
        # is not the recipient's or has no inbox item.
        def find_for_recipient_communication(recipient_id:, communication_id:, lock: false)
          relation = for_recipient(recipient_id)
          relation = relation.lock if lock
          relation.find_by(communication_id:)
        end
      end
    end
  end
end
