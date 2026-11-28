# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Requests
        # Per-recipient resolve/unresolve, addressed by the communication's idempotency
        # namespace (recipient, notification type, host event identity).
        ResolveForEvent = Data.define(
          :recipient_id,
          :notification_type_key,
          :host_event_identity
        ) do
          def self.build(recipient_id:, notification_type_key:, host_event_identity:)
            new(
              recipient_id:,
              notification_type_key:,
              host_event_identity:
            ).freeze
          end
        end
      end
    end
  end
end
