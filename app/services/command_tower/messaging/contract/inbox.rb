# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      # Inbox view state keyed by communication. This contract emits no audit:
      # a caller that mutates (mark_viewed_for_communication) must be a workflow
      # that owns the audit decision.
      module Inbox
        class << self
          # true/false for a live inbox item; nil when the communication is
          # missing, not the recipient's, deleted, or not inbox-backed.
          def viewed_for_communication?(request)
            guarded("inbox.viewed_for_communication", request, Requests::ViewedForCommunication) do
              CommandTower::Messaging::Inbox.viewed_for_communication(
                recipient_id: request.recipient_id,
                communication_id: request.communication_id
              )
            end
          end

          # Idempotent. Returns Results::InboxViewMark, or nil when the communication
          # is missing, not the recipient's, deleted, or not inbox-backed.
          def mark_viewed_for_communication(request)
            guarded("inbox.mark_viewed_for_communication", request, Requests::MarkViewedForCommunication) do
              item = CommandTower::Messaging::Inbox.mark_viewed_for_communication(
                recipient_id: request.recipient_id,
                communication_id: request.communication_id
              )
              item && view_mark(item)
            end
          end

          # Per recipient, idempotent, never touches viewed_at, emits no audit (the
          # calling host owns it). Returns Results::InboxResolution, or nil when there
          # is no live inbox item for the recipient and event. Badge sync scheduling
          # belongs to the scheduler, which is a no-op while impersonating.
          def resolve_for_event(request)
            guarded("inbox.resolve_for_event", request, Requests::ResolveForEvent) do
              resolution(CommandTower::Messaging::Inbox.resolve_for_event(**event_args(request)))
            end
          end

          # Inverse of resolve_for_event; same guarantees and nil rule.
          def unresolve_for_event(request)
            guarded("inbox.unresolve_for_event", request, Requests::ResolveForEvent) do
              resolution(CommandTower::Messaging::Inbox.unresolve_for_event(**event_args(request)))
            end
          end

          # Read-only, no audit. Returns Results::InboxDocument carrying the catalog 2
          # UI::Document, or nil when the communication is missing, not the recipient's,
          # deleted or archived, not inbox-backed, or its type has no MessageDefinition.
          def document_for_communication(request)
            guarded("inbox.document_for_communication", request, Requests::DocumentForCommunication) do
              item = CommandTower::Messaging::Inbox::Scope.find_for_recipient_communication(
                recipient_id: request.recipient_id,
                communication_id: request.communication_id
              )
              item && inbox_document(item, request)
            end
          end

          private

          def inbox_document(item, request)
            return nil if item.deleted? || item.archived?

            communication = item.communication
            return nil unless communication.message_definition_backed?

            document = CommandTower::Messaging::Rendering::InboxDocumentRenderer.render(
              communication:, recipient_id: request.recipient_id, ui_catalog: 2, impersonating: request.impersonating
            )
            return nil unless document.is_a?(CommandTower::UI::Document)

            Results::InboxDocument.new(
              communication_id: communication.id, inbox_item_id: item.id, document:
            ).freeze
          end

          def guarded(operation, request, expected_class, &)
            ensure_request!(request, expected_class)
            validate!(request)
            Observability::OperationLogger.around(operation:, request:, &)
          end

          def view_mark(item)
            Results::InboxViewMark.new(
              communication_id: item.communication_id,
              inbox_item_id: item.id,
              viewed: !item.viewed_at.nil?,
              newly_viewed: item.newly_viewed
            ).freeze
          end

          def event_args(request)
            {
              recipient_id: request.recipient_id,
              notification_type_key: request.notification_type_key,
              host_event_identity: request.host_event_identity
            }
          end

          def resolution(result)
            return nil if result.nil?

            Results::InboxResolution.new(
              communication_id: result.communication_id,
              inbox_item_id: result.inbox_item_id,
              resolved: result.resolved,
              changed: result.changed
            ).freeze
          end

          def ensure_request!(request, expected_class)
            return if request.is_a?(expected_class)

            raise Contract::ValidationError, "expected #{expected_class}, got #{request.class}"
          end

          def validate!(request)
            if request.is_a?(Requests::ResolveForEvent)
              validate_event!(request)
              return
            end

            raise Contract::ValidationError, "communication_id is required" if request.communication_id.nil?
            raise Contract::ValidationError, "recipient_id is required" if request.recipient_id.nil?
          end

          def validate_event!(request)
            raise Contract::ValidationError, "recipient_id is required" if request.recipient_id.nil?

            %i[notification_type_key host_event_identity].each do |field|
              raise Contract::ValidationError, "#{field} is required" if request.public_send(field).to_s.strip.empty?
            end
          end
        end
      end
    end
  end
end
