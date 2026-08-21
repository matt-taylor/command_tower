# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class UpdateEmailWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, email:, scope_value: nil)
            resolved = IdentityMutation.resolve_target(id:, principal: user, scope_value:)
            return resolved if resolved.is_a?(CommandTower::Workflows::WorkflowResult)

            target = resolved.user

            transaction do
              result = CommandTower::Services::Admin::Users::UpdateEmail.call(
                user: target,
                email:
              )
              fail_transaction!(IdentityMutation.map_service_failure(result)) unless result.success?

              updated = result.data[:user]
              if result.data[:changed]
                audit(
                  :admin_user_email_changed,
                  subject: updated,
                  affected_user: updated,
                  changes: {},
                  metadata: { email_changed: true },
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
