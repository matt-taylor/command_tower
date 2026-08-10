# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Communications
        # Thin job entry for async ProduceMany units. Reloads User by id then Produce.
        class ProduceRecipientWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(
            user_id:,
            notification_type_key:,
            campaign_identity:,
            title:,
            body:,
            platform_enabled_channels:,
            metadata: nil
          )
            user = User.find_by(id: user_id)
            unless user
              return failure(
                errors: [CommandTower::Errors::NotFoundError.new],
                http_status: :not_found,
                meta: { propagate_to_job: false }
              )
            end

            result = CommandTower::Services::Messaging::Communications::Produce.call(
              user:,
              notification_type_key:,
              host_event_identity: "#{campaign_identity}/#{user.id}",
              title:,
              body:,
              metadata:,
              platform_enabled_channels:,
            )

            unless result.success?
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(result.errors.first),
                meta: { propagate_to_job: false }
              )
            end

            success(
              payload: {
                "communicationId" => result.data[:communication_id],
                "inboxItemId" => result.data[:inbox_item_id],
                "userId" => user.id,
              },
              http_status: :ok
            )
          end
        end
      end
    end
  end
end
