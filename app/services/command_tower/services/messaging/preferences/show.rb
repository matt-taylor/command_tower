# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Preferences
        class Show < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            recipient_result = CommandTower::Services::Messaging::Recipients.call(user: user)
            unless recipient_result.success?
              context.fail!(application_error: recipient_result.errors.first)
              return
            end

            catalog = CommandTower::Messaging::Preferences.catalog(
              recipient_id: recipient_result.data[:recipient_id],
              platform_enabled_channels: PlatformEnabledChannels.call,
            )

            context.catalog = catalog
          rescue CommandTower::Messaging::Preferences::UnknownTypeError => error
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
