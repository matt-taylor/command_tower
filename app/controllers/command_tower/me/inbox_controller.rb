# frozen_string_literal: true

module CommandTower
  module Me
    class InboxController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def index
        deserialized = CommandTower::Deserializers::Messaging::Inbox::ListDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(CommandTower::Workflows::Messaging::Inbox::ListWorkflow.call(
          user: current_user, limit: deserialized.input.limit, offset: deserialized.input.offset, scope: deserialized.input.scope
        ))
      end

      def show
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::ShowWorkflow)
      end

      def open
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::OpenWorkflow)
      end

      def archive
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::ArchiveWorkflow)
      end

      def destroy
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::DeleteWorkflow)
      end

      def unread_count
        render_application_result(CommandTower::Workflows::Messaging::Inbox::UnreadCountWorkflow.call(user: current_user))
      end

      def bulk_read
        run_bulk_workflow(CommandTower::Workflows::Messaging::Inbox::BulkReadWorkflow)
      end

      def bulk_unread
        run_bulk_workflow(CommandTower::Workflows::Messaging::Inbox::BulkUnreadWorkflow)
      end

      def bulk_archive
        run_bulk_workflow(CommandTower::Workflows::Messaging::Inbox::BulkArchiveWorkflow)
      end

      def bulk_restore
        run_bulk_workflow(CommandTower::Workflows::Messaging::Inbox::BulkRestoreWorkflow)
      end

      def bulk_delete
        run_bulk_workflow(CommandTower::Workflows::Messaging::Inbox::BulkDeleteWorkflow)
      end

      private

      def run_item_workflow(workflow)
        deserialized = CommandTower::Deserializers::Messaging::Inbox::ShowDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(workflow.call(user: current_user, inbox_item_id: deserialized.input.inbox_item_id))
      end

      def run_bulk_workflow(workflow)
        deserialized = CommandTower::Deserializers::Messaging::Inbox::BulkIdsDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(workflow.call(user: current_user, inbox_item_ids: deserialized.input.inbox_item_ids))
      end

      def render_deserializer_errors
        render_application_result(CommandTower::Workflows::WorkflowResult.failure(
          errors: [CommandTower::Errors::ValidationError.new(details: { base: "Invalid request parameters" })],
          http_status: :unprocessable_entity
        ))
      end
    end
  end
end
