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

          def ensure_request!(request, expected_class)
            return if request.is_a?(expected_class)

            raise Contract::ValidationError, "expected #{expected_class}, got #{request.class}"
          end

          def validate!(request)
            raise Contract::ValidationError, "communication_id is required" if request.communication_id.nil?
            raise Contract::ValidationError, "recipient_id is required" if request.recipient_id.nil?
          end
        end
      end
    end
  end
end
