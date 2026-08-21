# frozen_string_literal: true

module CommandTower
  module Configuration
    module AdminScope
      class ToolRegistration
        REQUIRED_HOOKS = %i[options validate availability narrow_users narrow_audit affected_users_in_scope].freeze

        attr_accessor :options, :validate, :availability, :narrow_users, :narrow_audit,
          :affected_users_in_scope, :host_context_type

        def validate!(tool_id:)
          missing = REQUIRED_HOOKS.reject { |hook| callable?(public_send(hook)) }
          return self if missing.empty?

          raise CommandTower::AdminScope::InvalidToolRegistrationError,
            "admin scope registration for #{tool_id} is missing hooks: #{missing.join(", ")}"
        end

        private

        def callable?(value)
          value.respond_to?(:call)
        end
      end
    end
  end
end
