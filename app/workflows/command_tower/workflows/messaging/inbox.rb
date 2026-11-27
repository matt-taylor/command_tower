# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Inbox
        class BaseWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def self.inherited(subclass)
            super
            subclass.retry_strategy :none
          end

          private

          def result_or_failure(result)
            return result if result.success?

            failure(errors: result.errors, http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(result.errors.first))
          end

          # Read after the mutation so the client updates its badge from the same response.
          def success_with_unread_count(user:, payload:)
            count_result = CommandTower::Services::Messaging::Inbox::UnreadCount.call(user:)
            return result_or_failure(count_result) unless count_result.success?

            success(
              payload:,
              meta: CommandTower::Serializers::Messaging::Inbox::UnreadCountMetaSerializer.serialize(count_result.data),
              http_status: :ok
            )
          end
        end

        class ListWorkflow < BaseWorkflow
          def call(user:, limit:, offset:, scope:)
            result = CommandTower::Services::Messaging::Inbox::List.call(user:, limit:, offset:, scope:)
            return result_or_failure(result) unless result.success?

            payload = result.data[:items].map { |item| CommandTower::Serializers::Messaging::Inbox::EntrySerializer.serialize(item) }
            meta = CommandTower::Serializers::Messaging::Inbox::PaginationMetaSerializer.serialize(result.data[:pagination])
            success(payload:, meta:, http_status: :ok)
          end
        end

        class ConversationWorkflow < BaseWorkflow
          # `impersonating` comes from the authenticated boundary; nil (unknown) redacts.
          def call(user:, key:, scope:, around: nil, before_id: nil, after_id: nil, limit: nil, impersonating: nil)
            result = CommandTower::Services::Messaging::Inbox::Conversation.call(
              user:, key:, scope:, around:, before_id:, after_id:, limit:,
              ui_catalog: CommandTower::Current.ui_catalog, impersonating:,
            )
            return result_or_failure(result) unless result.success?

            success(
              payload: CommandTower::Serializers::Messaging::Inbox::ConversationSerializer.serialize(result.data[:conversation]),
              http_status: :ok,
            )
          end
        end

        class ShowWorkflow < BaseWorkflow
          # `impersonating` comes from the authenticated boundary; nil (unknown) redacts.
          def call(user:, inbox_item_id:, impersonating: nil)
            result = CommandTower::Services::Messaging::Inbox::Show.call(
              user:, inbox_item_id:, ui_catalog: CommandTower::Current.ui_catalog, impersonating:
            )
            return result_or_failure(result) unless result.success?

            success(payload: CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(result.data[:item]), http_status: :ok)
          end
        end

        class OpenWorkflow < ShowWorkflow
          def call(user:, inbox_item_id:, impersonating: nil)
            impersonated = CommandTower::Current.impersonation_active == true
            result = CommandTower::Services::Messaging::Inbox::Open.call(
              user:, inbox_item_id:, mark_viewed: !impersonated,
              ui_catalog: CommandTower::Current.ui_catalog, impersonating:
            )
            return result_or_failure(result) unless result.success?

            audit_first_view(user:, inbox_item_id:, result:) unless impersonated

            success_with_unread_count(
              user:, payload: CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(result.data[:item])
            )
          end

          private

          # One event per first view, for every inbox type. Metadata carries ids only.
          def audit_first_view(user:, inbox_item_id:, result:)
            return unless result.data[:newly_viewed]

            audit(
              :messaging_inbox_item_viewed,
              affected_user: user,
              changes: {},
              metadata: { inbox_item_id:, communication_id: result.data[:communication_id] }
            )
          end
        end

        # Scroll-read. While impersonating nothing is recorded: the skip answers before any
        # id is looked at, so it never depends on the ids being valid.
        class RecordViewsWorkflow < BaseWorkflow
          def call(user:, inbox_item_ids:, impersonated: false)
            return skipped_result(user:) if impersonated

            result = CommandTower::Services::Messaging::Inbox::RecordViews.call(user:, inbox_item_ids:)
            return result_or_failure(result) unless result.success?

            data = result.data[:record_views]
            audit_first_views(user:, newly_viewed: data[:newly_viewed])
            success_with_unread_count(user:, payload: CommandTower::Serializers::Messaging::Inbox::RecordViewsSerializer.serialize(data))
          end

          private

          def skipped_result(user:)
            payload = CommandTower::Serializers::Messaging::Inbox::RecordViewsSerializer.serialize(
              viewed_ids: [], unavailable_ids: [], changed_count: 0, skipped: "impersonating"
            )
            success_with_unread_count(user:, payload:)
          end

          # One event per first view, ids only (same shape as OpenWorkflow).
          def audit_first_views(user:, newly_viewed:)
            newly_viewed.each do |entry|
              audit(
                :messaging_inbox_item_viewed,
                affected_user: user,
                changes: {},
                metadata: { inbox_item_id: entry[:id], communication_id: entry[:communication_id] }
              )
            end
          end
        end

        # Marks everything unread up to the client's watermark viewed. Reversible, so it stays
        # allowed while impersonating (the audit policy lands with the impersonation slice).
        class MarkAllReadWorkflow < BaseWorkflow
          def call(user:, up_to:)
            result = CommandTower::Services::Messaging::Inbox::MarkAllRead.call(user:, up_to:)
            return result_or_failure(result) unless result.success?

            success_with_unread_count(
              user:, payload: CommandTower::Serializers::Messaging::Inbox::BulkResultSerializer.serialize(result.data[:bulk_result])
            )
          end
        end

        class ArchiveWorkflow < BaseWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Archive.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success_with_unread_count(
              user:, payload: CommandTower::Serializers::Messaging::Inbox::ItemSerializer.serialize(result.data[:item])
            )
          end
        end

        class DeleteWorkflow < BaseWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Delete.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success_with_unread_count(user:, payload: nil)
          end
        end

        class UnreadCountWorkflow < BaseWorkflow
          def call(user:)
            result = CommandTower::Services::Messaging::Inbox::UnreadCount.call(user:)
            return result_or_failure(result) unless result.success?

            success(payload: CommandTower::Serializers::Messaging::Inbox::UnreadCountSerializer.serialize(result.data), http_status: :ok)
          end
        end

        { BulkReadWorkflow: :BulkRead, BulkUnreadWorkflow: :BulkUnread, BulkArchiveWorkflow: :BulkArchive,
          BulkRestoreWorkflow: :BulkRestore, BulkDeleteWorkflow: :BulkDelete }.each do |workflow_name, service_name|
          const_set(workflow_name, Class.new(BaseWorkflow) do
            define_method(:call) do |user:, inbox_item_ids:|
              result = CommandTower::Services::Messaging::Inbox.const_get(service_name).call(user:, inbox_item_ids:)
              return result_or_failure(result) unless result.success?

              success_with_unread_count(
                user:, payload: CommandTower::Serializers::Messaging::Inbox::BulkResultSerializer.serialize(result.data[:bulk_result])
              )
            end
          end)
        end
      end
    end
  end
end
