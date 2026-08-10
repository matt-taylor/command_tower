# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Messaging
        class CreateAnnouncementWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(input:)
            user_ids = resolve_user_ids(input)
            platform_enabled_channels =
              CommandTower::Services::Messaging::Preferences::PlatformEnabledChannels.call

            result = CommandTower::Services::Messaging::Communications::ProduceMany.call(
              user_ids:,
              notification_type_key: input.notification_type_key,
              campaign_identity: input.campaign_identity,
              title: input.title,
              body: input.body,
              metadata: input.metadata,
              platform_enabled_channels:,
              execution_mode: input.execution_mode,
            )

            unless result.success?
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(result.errors.first)
              )
            end

            success(
              payload: CommandTower::Serializers::Admin::Messaging::AnnouncementResponseSerializer.serialize(
                result.data
              ),
              http_status: :accepted
            )
          end

          private

          def resolve_user_ids(input)
            selection =
              case input.audience
              when :user_ids
                { mode: :user_ids, ids: input.user_ids }
              when :all_users
                { mode: :all_users }
              else
                { mode: :none }
              end

            Array(CommandTower.config.messaging.resolve_announcement_audience.call(selection)).map { |id| Integer(id) }
          rescue ArgumentError, TypeError
            []
          end
        end
      end
    end
  end
end
