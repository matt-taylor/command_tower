# frozen_string_literal: true

module CommandTower
  module Workflows
    module Audit
      module Events
        class ShowForUserWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:, id:)
            shown = CommandTower::Services::Audit::Events::Show.call(
              viewer_scope: :user,
              affected_user_id: user.id,
              id:
            )
            return result_or_failure(shown) unless shown.success?

            projected = CommandTower::Services::Audit::Events::Project.call(
              event: shown.data[:event],
              viewer: :user
            )
            return result_or_failure(projected) unless projected.success?

            payload = CommandTower::Serializers::Audit::Events::EventSerializer.serialize(
              projected.data[:projection]
            )
            success(payload:, http_status: :ok)
          end

          private

          def result_or_failure(result)
            failure(
              errors: result.errors,
              http_status: CommandTower::Workflows::Audit::ErrorMapping.http_status_for(result.errors.first)
            )
          end
        end
      end
    end
  end
end
