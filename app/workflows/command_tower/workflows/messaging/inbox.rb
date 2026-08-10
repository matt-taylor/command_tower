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
        end

        class ListWorkflow < BaseWorkflow
          def call(user:, limit:, offset:, scope:)
            result = CommandTower::Services::Messaging::Inbox::List.call(user:, limit:, offset:, scope:)
            return result_or_failure(result) unless result.success?

            payload = result.data[:items].map { |item| CommandTower::Serializers::Messaging::Inbox::ItemSerializer.serialize(item) }
            meta = CommandTower::Serializers::Messaging::Inbox::PaginationMetaSerializer.serialize(result.data[:pagination])
            success(payload:, meta:, http_status: :ok)
          end
        end

        class ShowWorkflow < BaseWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Show.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success(payload: CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(result.data[:item]), http_status: :ok)
          end
        end

        class OpenWorkflow < ShowWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Open.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success(payload: CommandTower::Serializers::Messaging::Inbox::DetailSerializer.serialize(result.data[:item]), http_status: :ok)
          end
        end

        class ArchiveWorkflow < BaseWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Archive.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success(payload: CommandTower::Serializers::Messaging::Inbox::ItemSerializer.serialize(result.data[:item]), http_status: :ok)
          end
        end

        class DeleteWorkflow < BaseWorkflow
          def call(user:, inbox_item_id:)
            result = CommandTower::Services::Messaging::Inbox::Delete.call(user:, inbox_item_id:)
            return result_or_failure(result) unless result.success?

            success(payload: nil, http_status: :ok)
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

              success(
                payload: CommandTower::Serializers::Messaging::Inbox::BulkResultSerializer.serialize(result.data[:bulk_result]),
                http_status: :ok
              )
            end
          end)
        end
      end
    end
  end
end
