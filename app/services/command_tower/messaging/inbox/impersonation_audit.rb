# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      # One audit event per request when an operator changes a recipient's inbox while impersonating.
      # Called inside the mutation transaction: the audit write is part of it, so a failed audit
      # (including a missing admin attribution) rolls the change back. Metadata is ids only.
      class ImpersonationAudit
        EVENT = :messaging_inbox_changed_while_impersonating

        # Intentionally independent from Mutator::BULK_MAX_IDS: the audit payload is size-capped
        # (a mark-all-read can change far more rows than a bulk request may name).
        MAX_AUDITED_IDS = 50

        class << self
          def impersonating?
            CommandTower::Current.impersonation_active == true
          end

          # No-op for a normal session or when nothing changed.
          def record_changes(recipient_id:, action:, changed_ids:, up_to: nil)
            return unless impersonating?
            return if changed_ids.empty?

            metadata = {
              action: action.to_s,
              inbox_item_ids: changed_ids.first(MAX_AUDITED_IDS),
              changed_count: changed_ids.size
            }
            metadata[:up_to] = up_to unless up_to.nil?
            metadata[:truncated] = true if changed_ids.size > MAX_AUDITED_IDS

            CommandTower::Audit::Emit.call(name: EVENT, affected_user: recipient_id, metadata:)
          end
        end
      end
    end
  end
end
