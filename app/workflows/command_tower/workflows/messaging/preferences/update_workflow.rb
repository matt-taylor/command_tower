# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Preferences
        class UpdateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(user:, notification_type_key:, preference_state:)
            result = CommandTower::Services::Messaging::Preferences::Update.call(
              user:,
              notification_type_key:,
              preference_state:,
            )

            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(error)
              )
            end

            payload = {
              notification: CommandTower::Serializers::Messaging::Preferences::NotificationSerializer.serialize(
                result.data[:notification],
              ),
            }

            success(payload:, http_status: :ok)
          end
        end
      end
    end
  end
end
