# frozen_string_literal: true

module CommandTower
  module Logging
    module Projection
      DROP = %i[event_uuid layer log_lifecycle log_level].freeze

      module_function

      def call(event)
        payload = symbolize(event.payload)
        projected = { event: event.name }

        copy_if_present(projected, payload, :subject)
        copy_if_present(projected, payload, :execution_uuid)
        copy_if_present(projected, payload, :correlation_id)
        copy_if_present(projected, payload, :outcome)
        copy_if_present(projected, payload, :duration_ms)
        copy_if_present(projected, payload, :user_id)
        copy_if_present(projected, payload, :error_class)
        copy_if_present(projected, payload, :error_codes)
        copy_if_present(projected, payload, :causation_id)
        copy_if_present(projected, payload, :originating_administrator_id)

        request_id = payload[:request_id]
        if !request_id.nil? && request_id != payload[:correlation_id]
          projected[:request_id] = request_id
        end

        source = payload[:source]
        projected[:source] = source if !source.nil? && source.to_s != "http"

        effective = payload[:effective_user_id]
        projected[:effective_user_id] = effective if !effective.nil? && effective != payload[:user_id]

        projected[:impersonation_active] = true if payload[:impersonation_active] == true

        payload.each do |key, value|
          next if DROP.include?(key)
          next if projected.key?(key)
          next if value.nil?
          next if key == :impersonation_active
          next if key == :source
          next if key == :request_id
          next if key == :effective_user_id

          projected[key] = value
        end

        projected
      end

      def symbolize(payload)
        hash = payload.respond_to?(:to_h) ? payload.to_h : {}
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_sym] = value
        end
      end

      def copy_if_present(projected, payload, key)
        value = payload[key]
        projected[key] = value unless value.nil?
      end
      private_class_method :symbolize, :copy_if_present
    end
  end
end
