# frozen_string_literal: true

module CommandTower
  module Workflows
    module Audit
      module Events
        class ListForUserWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:, limit:, offset:, actions: nil, occurred_after: nil, occurred_before: nil, subject_types: nil)
            listed = CommandTower::Services::Audit::Events::List.call(
              viewer_scope: :user,
              affected_user_id: user.id,
              limit:,
              offset:,
              actions:,
              occurred_after:,
              occurred_before:,
              subject_types:
            )
            return result_or_failure(listed) unless listed.success?

            payload = listed.data[:events].filter_map do |event|
              projected = CommandTower::Services::Audit::Events::Project.call(event:, viewer: :user)
              return result_or_failure(projected) unless projected.success?

              CommandTower::Serializers::Audit::Events::EventSerializer.serialize(projected.data[:projection])
            end
            meta = CommandTower::Serializers::Audit::Events::PaginationMetaSerializer.serialize(listed.data[:pagination])
            success(payload:, meta:, http_status: :ok)
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
