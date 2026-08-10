# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Communications
        # Shared multi-host produce adapter: resolve recipient → Messaging.accept → ServiceResult.
        # Hosts supply platform_enabled_channels (deployment policy). Does not own catalog content
        # or product workflows.
        class Produce < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :notification_type_key, is_a: String, required: true
          validate :host_event_identity, is_a: String, required: true
          validate :title, is_a: String, required: true
          validate :body, is_a: String, required: true
          validate :metadata, is_a: Hash, required: false
          validate :platform_enabled_channels, is_a: Array, required: true

          def call
            recipient_result = CommandTower::Services::Messaging::Recipients.call(user: user)
            unless recipient_result.success?
              context.fail!(application_error: recipient_result.errors.first)
              return
            end

            accept_result = CommandTower::Messaging.accept(
              recipient_id: recipient_result.data[:recipient_id],
              notification_type_key:,
              host_event_identity:,
              title:,
              body:,
              metadata:,
              preference_state: nil,
              platform_enabled_channels:,
              message_overrides: nil,
            )

            # Use communication_status — ServiceResult strips Interactor reserved :status.
            context.communication_id = accept_result.communication_id
            context.destination_plan_id = accept_result.destination_plan_id
            context.recipient_id = accept_result.recipient_id
            context.notification_type_key = accept_result.notification_type_key
            context.host_event_identity = accept_result.host_event_identity
            context.communication_status = accept_result.status
            context.idempotent_replay = accept_result.idempotent_replay
            context.inbox_item_id = accept_result.inbox_item_id
            context.selected_channels = accept_result.selected_channels
            context.inbox_selected = accept_result.inbox_selected
          rescue CommandTower::Messaging::Accept::ValidationError => error
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { messaging: error.message }))
          rescue CommandTower::Messaging::Accept::UnknownTypeError,
                 CommandTower::Messaging::Accept::InvalidPreferenceError,
                 CommandTower::Messaging::Accept::IllegalOverrideError,
                 CommandTower::Messaging::Accept::ImpossibleMandatoryPlanError
            context.fail!(application_error: CommandTower::Errors::Messaging::AcceptRejectedError.new)
          rescue CommandTower::Messaging::Accept::IdempotencyConflictError
            context.fail!(application_error: CommandTower::Errors::Messaging::IdempotencyConflictError.new)
          rescue CommandTower::Messaging::Accept::PersistenceError,
                 CommandTower::Messaging::Accept::InvariantError
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          rescue CommandTower::Messaging::Accept::Error
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end
        end
      end
    end
  end
end
