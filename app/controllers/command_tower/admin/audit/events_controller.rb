# frozen_string_literal: true

module CommandTower
  module Admin
    module Audit
      class EventsController < CommandTower::Admin::ApplicationController
        def index
          deserialized = CommandTower::Deserializers::Audit::Events::AdminListDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Audit::Events::ListForAdminWorkflow.call(
              limit: deserialized.input.limit,
              offset: deserialized.input.offset,
              actions: deserialized.input.actions,
              occurred_after: deserialized.input.occurred_after,
              occurred_before: deserialized.input.occurred_before,
              subject_types: deserialized.input.subject_types,
              affected_user_id: deserialized.input.affected_user_id,
              actor_user_id: deserialized.input.actor_user_id,
              originating_administrator_id: deserialized.input.originating_administrator_id,
              attribution_mode: deserialized.input.attribution_mode,
              user: current_user,
              scope_value: deserialized.input.scope_value
            )
          )
        end

        def show
          deserialized = CommandTower::Deserializers::Audit::Events::ShowDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Audit::Events::ShowForAdminWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              scope_value: deserialized.input.scope_value
            )
          )
        end

        def filter_options
          render_application_result(
            CommandTower::Workflows::Audit::Events::FilterOptionsForAdminWorkflow.call
          )
        end

        private

        def render_deserializer_errors
          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [CommandTower::Errors::ValidationError.new(details: { base: "Invalid request parameters" })],
              http_status: :unprocessable_entity
            )
          )
        end
      end
    end
  end
end
