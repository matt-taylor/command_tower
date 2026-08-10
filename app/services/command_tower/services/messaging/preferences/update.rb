# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Preferences
        class Update < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :notification_type_key, is_a: String, required: true
          validate :preference_state, is_a: Hash, required: true

          def call
            recipient_result = CommandTower::Services::Messaging::Recipients.call(user: user)
            unless recipient_result.success?
              context.fail!(application_error: recipient_result.errors.first)
              return
            end

            notification = CommandTower::Messaging::Preferences.update(
              recipient_id: recipient_result.data[:recipient_id],
              notification_type_key:,
              preference_state:,
              platform_enabled_channels: PlatformEnabledChannels.call,
            )

            context.notification = notification
          rescue CommandTower::Messaging::Preferences::UnknownTypeError,
                 CommandTower::Messaging::Preferences::NotSettingsVisibleError
            context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
          rescue CommandTower::Messaging::Preferences::InvalidPreferenceWriteError => error
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { messaging: error.message }))
          rescue CommandTower::Messaging::Preferences::InvalidPreferenceStateError => error
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { messaging: error.message }))
          rescue CommandTower::Messaging::Preferences::StoreError
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          rescue CommandTower::Messaging::Preferences::Error
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end
        end
      end
    end
  end
end
