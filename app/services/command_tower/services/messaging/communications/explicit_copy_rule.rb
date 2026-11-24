# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Communications
        # D17 for the Produce family: a MessageDefinition-backed type derives title and body, so
        # explicit copy is rejected in strict mode (dev/test) and dropped with an ids-only log
        # otherwise. Undefined types are untouched.
        module ExplicitCopyRule
          module_function

          def defined_type?(notification_type_key)
            return false unless CommandTower::Messaging::NotificationTypes.registered?(notification_type_key)

            message = CommandTower::Messaging::NotificationTypes.lookup(notification_type_key).message
            klass = message&.safe_constantize
            klass.is_a?(Class) && klass < CommandTower::Messaging::MessageDefinition
          end

          def explicit_copy?(title, body)
            [title, body].any? { |value| !value.nil? && !(value.respond_to?(:strip) && value.strip.empty?) }
          end

          def violation?(notification_type_key:, title:, body:)
            explicit_copy?(title, body) && defined_type?(notification_type_key)
          end

          def strict?
            CommandTower.config.messaging.strict_definitions
          end

          def failure
            CommandTower::Errors::ValidationError.new(
              details: { messaging: "title and body must not be supplied for a defined type" }
            )
          end

          def log_ignored(notification_type_key:, **ids)
            CommandTower::Messaging::Contract::Observability::Publisher.warn(
              event: "messaging.produce.produce_explicit_copy_ignored",
              notification_type_key:,
              **ids
            )
          end
        end
      end
    end
  end
end
