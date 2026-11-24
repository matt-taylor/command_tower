# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Unsubscribe
        # Turns the email channel off for one user and one notification type, through the existing
        # preferences update. Every refusal (unknown user, unknown type, mandatory, not user
        # configurable, email not allowed, not settings-visible) is the same ValidationError, so a
        # caller cannot tell them apart. `changed` is false when email was already off.
        class OptOutOfEmail < CommandTower::Services::ApplicationService
          validate :user_id, is_a: Integer, required: true
          validate :notification_type_key, is_a: String, required: true

          def call
            user = User.find_by(id: user_id)
            context.fail!(application_error: invalid_error) unless user && eligible?

            context.user = user
            context.changed = !already_off?
            update_preference(user) if context.changed
          end

          private

          def eligible?
            declaration = CommandTower::Messaging::NotificationTypes.lookup(notification_type_key)
            CommandTower::Messaging::Rendering::UnsubscribeHeaders.eligible?(declaration)
          rescue CommandTower::Messaging::NotificationTypes::NotFoundError
            false
          end

          def already_off?
            evaluation = CommandTower::Messaging::Preferences.resolve(
              notification_type_key:,
              recipient_id: user_id
            )
            evaluation.effective_preference_state.fetch("channels").fetch("email", true) == false
          end

          def update_preference(user)
            update = CommandTower::Services::Messaging::Preferences::Update.call(
              user:,
              notification_type_key:,
              preference_state: { "channels" => { "email" => false } }
            )
            return if update.success?

            context.fail!(application_error: collapse_refusal(update.errors.first))
          end

          # A refusal from the preferences update is indistinguishable from any other refusal.
          def collapse_refusal(error)
            refusal = error.is_a?(CommandTower::Errors::NotFoundError) || error.is_a?(CommandTower::Errors::ValidationError)
            refusal ? invalid_error : error
          end

          def invalid_error
            CommandTower::Errors::ValidationError.new(details: { token: "invalid" })
          end
        end
      end
    end
  end
end
