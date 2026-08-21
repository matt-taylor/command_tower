# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class ListAssignableRolesWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call
            listed = CommandTower::Services::Admin::Users::ListAssignableRoles.call
            unless listed.success?
              return failure(
                errors: listed.errors,
                http_status: ErrorMapping.http_status_for(listed.errors.first)
              )
            end

            success(
              payload: CommandTower::Serializers::Admin::Users::AssignableRolesSerializer.serialize(
                listed.data[:roles]
              ),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end
