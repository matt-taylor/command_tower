# frozen_string_literal: true

module CommandTower
  module AdminScope
    module ManifestProjection
      IMPERSONATION_DISABLED_REASON = "Admin tools are unavailable while impersonating a user."

      module_function

      def call(definition:, principal:)
        scope_payload = scope_payload_for(definition)
        unscoped_unregistered = scope_payload.nil? && !admin_scope_registered?(definition.id)

        availability = availability_for(definition, principal:)
        scope_options = scope_options_for(definition, principal:)

        payload = {
          scope: scope_payload,
          availability:,
          scope_options:
        }.compact

        if CommandTower::Current.impersonation_active
          payload[:availability] = {
            enabled: false,
            reason: IMPERSONATION_DISABLED_REASON
          }
          return payload
        end

        return {} if unscoped_unregistered

        payload
      end

      def scope_payload_for(definition)
        return unless definition.scope_required?

        {
          required: true,
          parameter: camelize_parameter(definition.scope_parameter),
          label: definition.scope_label
        }
      end
      private_class_method :scope_payload_for

      def availability_for(definition, principal:)
        return { enabled: true, reason: nil } unless admin_scope_registered?(definition.id)

        registration = CommandTower.config.admin_scope.fetch(definition.id)
        normalize_availability(registration.availability.call(principal:))
      end
      private_class_method :availability_for

      def scope_options_for(definition, principal:)
        return unless definition.scope_required? && admin_scope_registered?(definition.id)

        registration = CommandTower.config.admin_scope.fetch(definition.id)
        Array(registration.options.call(principal:)).map do |option|
          normalize_scope_option(option)
        end
      end
      private_class_method :scope_options_for

      def admin_scope_registered?(tool_id)
        CommandTower.config.admin_scope.registered?(tool_id)
      end
      private_class_method :admin_scope_registered?

      def normalize_availability(value)
        hash = value.is_a?(Hash) ? value : {}
        enabled = hash.fetch(:enabled, hash["enabled"])
        reason = hash.fetch(:reason, hash["reason"])
        {
          enabled: enabled != false,
          reason: reason.nil? ? nil : reason.to_s
        }
      end
      private_class_method :normalize_availability

      def normalize_scope_option(option)
        case option
        when AdminScope::ScopeOption
          { value: option.value, label: option.label }
        when Hash
          {
            value: option.fetch(:value, option["value"]).to_s,
            label: option.fetch(:label, option["label"]).to_s
          }
        else
          raise ArgumentError, "scope option must be ScopeOption or Hash, got #{option.class}"
        end
      end
      private_class_method :normalize_scope_option

      def camelize_parameter(parameter)
        parameter.to_s.camelize(:lower)
      end
      private_class_method :camelize_parameter
    end
  end
end
