# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class UpdateUsernameWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, username:, scope_value: nil)
            resolved = IdentityMutation.resolve_target(id:, principal: user, scope_value:)
            return resolved if resolved.is_a?(CommandTower::Workflows::WorkflowResult)

            target = resolved.user
            previous_username = target.username

            transaction do
              result = CommandTower::Services::Admin::Users::UpdateUsername.call(
                user: target,
                username:
              )
              fail_transaction!(IdentityMutation.map_service_failure(result)) unless result.success?

              updated = result.data[:user]
              if result.data[:changed]
                audit(
                  :admin_user_username_changed,
                  subject: updated,
                  affected_user: updated,
                  changes: { username: { from: previous_username, to: updated.username } },
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
