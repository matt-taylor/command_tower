# frozen_string_literal: true

module CommandTower
  module Admin
    module Users
      class IdentitiesController < CommandTower::Admin::ApplicationController
        def update_name
          deserialized = CommandTower::Deserializers::Admin::Users::UpdateNameDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Admin::Users::UpdateNameWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              first_name: deserialized.input.first_name,
              last_name: deserialized.input.last_name,
              scope_value: deserialized.input.scope_value
            )
          )
        end

        def update_username
          deserialized = CommandTower::Deserializers::Admin::Users::UpdateUsernameDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Admin::Users::UpdateUsernameWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              username: deserialized.input.username,
              scope_value: deserialized.input.scope_value
            )
          )
        end

        def update_email
          deserialized = CommandTower::Deserializers::Admin::Users::UpdateEmailDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Admin::Users::UpdateEmailWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              email: deserialized.input.email,
              scope_value: deserialized.input.scope_value
            )
          )
        end

        def update_email_validation
          deserialized = CommandTower::Deserializers::Admin::Users::UpdateEmailValidationDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Admin::Users::SetEmailValidatedWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              email_validated: deserialized.input.email_validated,
              scope_value: deserialized.input.scope_value
            )
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
