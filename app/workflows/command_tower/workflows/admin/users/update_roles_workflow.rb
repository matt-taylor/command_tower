# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class UpdateRolesWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, roles:, scope_value: nil)
            resolved = IdentityMutation.resolve_target(id:, principal: user, scope_value:)
            return resolved if resolved.is_a?(CommandTower::Workflows::WorkflowResult)

            target = resolved.user
            policy = CommandTower::Services::Admin::Users::RoleAssignmentPolicy.call(
              actor: user,
              target:,
              desired_roles: roles
            )
            return IdentityMutation.map_service_failure(policy) unless policy.success?

            transaction do
              result = CommandTower::Services::Admin::Users::ReplaceUserRoles.call(
                user: target,
                desired_roles: policy.data[:desired_roles]
              )
              fail_transaction!(IdentityMutation.map_service_failure(result)) unless result.success?

              updated = result.data[:user]
              if result.data[:changed]
                Array(result.data[:assigned_roles]).each do |role_name|
                  audit(
                    :role_assigned,
                    subject: updated,
                    affected_user: updated,
                    changes: { role: { from: nil, to: role_name.to_s } },
                    attribution_mode: :admin_direct
                  )
                end
                Array(result.data[:revoked_roles]).each do |role_name|
                  audit(
                    :role_revoked,
                    subject: updated,
                    affected_user: updated,
                    changes: { role: { from: role_name.to_s, to: nil } },
                    attribution_mode: :admin_direct
                  )
                end
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
