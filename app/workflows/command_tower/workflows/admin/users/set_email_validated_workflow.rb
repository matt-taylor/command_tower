# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class SetEmailValidatedWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, email_validated:, scope_value: nil)
            resolved = IdentityMutation.resolve_target(id:, principal: user, scope_value:)
            return resolved if resolved.is_a?(CommandTower::Workflows::WorkflowResult)

            target = resolved.user
            previous = target.email_validated

            transaction do
              result = CommandTower::Services::Admin::Users::SetEmailValidated.call(
                user: target,
                email_validated:
              )
              fail_transaction!(IdentityMutation.map_service_failure(result)) unless result.success?

              updated = result.data[:user]
              if result.data[:changed]
                audit(
                  :admin_user_email_validation_changed,
                  subject: updated,
                  affected_user: updated,
                  changes: { email_validated: { from: previous, to: updated.email_validated } },
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
