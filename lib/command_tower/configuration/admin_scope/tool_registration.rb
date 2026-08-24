# frozen_string_literal: true

module CommandTower
  module Configuration
    module AdminScope
      class ToolRegistration
        BASE_HOOKS = %i[options validate availability].freeze
        RESOURCE_NARROWING_HOOKS = %i[narrow_users narrow_audit affected_users_in_scope].freeze
        RESOURCE_SCOPED_TOOL_IDS = %w[users audit].freeze

        attr_accessor :options, :validate, :availability, :narrow_users, :narrow_audit,
          :affected_users_in_scope, :host_context_type

        def validate!(tool_id:)
          missing = required_hooks_for(tool_id).reject { |hook| callable?(public_send(hook)) }
          return self if missing.empty?

          raise CommandTower::AdminScope::InvalidToolRegistrationError,
            "admin scope registration for #{tool_id} is missing hooks: #{missing.join(", ")}"
        end

        private

        def required_hooks_for(tool_id)
          hooks = BASE_HOOKS.dup
          normalized = tool_id.to_s
          if RESOURCE_SCOPED_TOOL_IDS.include?(normalized) || resource_narrowing_hooks_present?
            hooks.concat(RESOURCE_NARROWING_HOOKS)
          end
          hooks
        end

        def resource_narrowing_hooks_present?
          RESOURCE_NARROWING_HOOKS.any? { |hook| !public_send(hook).nil? }
        end

        def callable?(value)
          value.respond_to?(:call)
        end
      end
    end
  end
end
