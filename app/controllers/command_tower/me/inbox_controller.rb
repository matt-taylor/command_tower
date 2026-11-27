# frozen_string_literal: true

module CommandTower
  module Me
    class InboxController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!
      # Inbox reads can carry per-recipient, impersonation-redacted content: never cache them.
      before_action :set_no_store, only: %i[index show open conversation unread_count]

      def index
        deserialized = CommandTower::Deserializers::Messaging::Inbox::ListDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(CommandTower::Workflows::Messaging::Inbox::ListWorkflow.call(
          user: current_user, limit: deserialized.input.limit, offset: deserialized.input.offset, scope: deserialized.input.scope
        ))
      end

      def conversation
        deserialized = CommandTower::Deserializers::Messaging::Inbox::ConversationDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        input = deserialized.input
        render_application_result(CommandTower::Workflows::Messaging::Inbox::ConversationWorkflow.call(
          user: current_user,
          key: input.key,
          scope: input.scope,
          around: input.around,
          before_id: input.before_id,
          after_id: input.after_id,
          limit: input.limit,
          impersonating: impersonating_flag,
        ))
      end

      def show
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::ShowWorkflow, impersonating: impersonating_flag)
      end

      def open
        run_item_workflow(CommandTower::Workflows::Messaging::Inbox::OpenWorkflow, impersonating: impersonating_flag)
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

      def views
        # Impersonation is decided before the body is validated.
        if CommandTower::Current.impersonation_active == true
          return render_application_result(CommandTower::Workflows::Messaging::Inbox::RecordViewsWorkflow.call(
            user: current_user, inbox_item_ids: [], impersonated: true
          ))
        end

        deserialized = CommandTower::Deserializers::Messaging::Inbox::BulkIdsDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(CommandTower::Workflows::Messaging::Inbox::RecordViewsWorkflow.call(
          user: current_user, inbox_item_ids: deserialized.input.inbox_item_ids
        ))
      end

      def mark_all_read
        deserialized = CommandTower::Deserializers::Messaging::Inbox::MarkAllReadDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(CommandTower::Workflows::Messaging::Inbox::MarkAllReadWorkflow.call(
          user: current_user, up_to: deserialized.input.up_to
        ))
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

      def run_item_workflow(workflow, **extra)
        deserialized = CommandTower::Deserializers::Messaging::Inbox::ShowDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(workflow.call(user: current_user, inbox_item_id: deserialized.input.inbox_item_id, **extra))
      end

      def set_no_store
        response.headers["Cache-Control"] = "no-store"
      end

      # From the authentication result: true while impersonating, false for a normal session,
      # nil when there is no auth context (unknown, which redacts).
      def impersonating_flag
        return nil if current_auth_context.nil?

        CommandTower::Current.impersonation_active == true
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
