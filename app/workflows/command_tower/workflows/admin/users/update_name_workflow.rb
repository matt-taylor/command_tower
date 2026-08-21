# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class UpdateNameWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, first_name:, last_name:, scope_value: nil)
            resolved = IdentityMutation.resolve_target(id:, principal: user, scope_value:)
            return resolved if resolved.is_a?(CommandTower::Workflows::WorkflowResult)

            target = resolved.user
            previous = { first_name: target.first_name, last_name: target.last_name }

            transaction do
              result = CommandTower::Services::Admin::Users::UpdateName.call(
                user: target,
                first_name:,
                last_name:
              )
              fail_transaction!(IdentityMutation.map_service_failure(result)) unless result.success?

              updated = result.data[:user]
              if result.data[:changed]
                audit(
                  :admin_user_name_changed,
                  subject: updated,
                  affected_user: updated,
                  changes: {
                    first_name: { from: previous[:first_name], to: updated.first_name },
                    last_name: { from: previous[:last_name], to: updated.last_name }
                  },
                  attribution_mode: :admin_direct
                )
              end

              success(
                payload: CommandTower::Serializers::Admin::Users::UserSerializer.serialize(updated),
                http_status: :ok
              )
            end
          end
        end
      end
    end
  end
end
