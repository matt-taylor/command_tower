# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        # Me self-test: Produce a host-registered push_delivery_test communication.
        # Does not bypass Messaging; does not talk to Expo directly.
        class SendSelfTest < CommandTower::Services::ApplicationService
          NOTIFICATION_TYPE_KEY = "push_delivery_test"
          TITLE = "Push notifications"
          BODY = "This is a test notification from your account."

          validate :user, is_a: User, required: true

          def call
            list_result = CommandTower::Services::Account::Push::List.call(user:)
            unless list_result.success?
              context.fail!(application_error: list_result.errors.first)
              return
            end

            if Array(list_result.data[:safe_views]).empty?
              context.fail!(application_error: CommandTower::Errors::Account::PushTestNoEndpointError.new)
              return
            end

            rate_result = CommandTower::Services::Account::Push::CheckSelfTestRateLimit.call(user:)
            unless rate_result.success?
              context.fail!(application_error: rate_result.errors.first)
              return
            end

            produce_result = CommandTower::Services::Messaging::Communications::Produce.call(
              user:,
              notification_type_key: NOTIFICATION_TYPE_KEY,
              host_event_identity: "push_delivery_test/#{user.id}/#{SecureRandom.uuid}",
              title: TITLE,
              body: BODY,
              metadata: {},
              platform_enabled_channels: CommandTower::Services::Messaging::Preferences::PlatformEnabledChannels.call,
            )
            unless produce_result.success?
              context.fail!(application_error: produce_result.errors.first)
              return
            end

            context.communication_id = produce_result.data[:communication_id]
            context.destination_plan_id = produce_result.data[:destination_plan_id]
            context.selected_channels = produce_result.data[:selected_channels]
            context.communication_status = produce_result.data[:communication_status]
          end
        end
      end
    end
  end
end
