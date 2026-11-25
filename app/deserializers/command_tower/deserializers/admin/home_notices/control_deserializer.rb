# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Admin
      module HomeNotices
        # Reads the kill-switch update `PATCH /admin/home-notices/:key {enabled: bool}`: the notice
        # `key` and a strict boolean `enabled`. Whether the key is a registered notice is the
        # workflow's decision.
        class ControlDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          KEY_FORMAT = /\A[a-z0-9_]+(\.[a-z0-9_]+)*\z/
          KEY_MAX_LENGTH = 128

          Input = Data.define(:key, :enabled)

          def call(params)
            key = unwrap(require_string(fetch_param(params, :key).value, field: :key))
            return key if deserializer_result?(key)
            return invalid(:key) unless KEY_FORMAT.match?(key) && key.length <= KEY_MAX_LENGTH

            enabled_input(fetch_param(params, :enabled).value, key)
          end

          private

          def enabled_input(enabled, key)
            return invalid(:enabled, code: "missing_required_fields") if enabled.nil?
            return invalid(:enabled) unless [true, false].include?(enabled)

            success(Input.new(key:, enabled:))
          end

          def invalid(field, code: "invalid_value")
            failure(errors: CommandTower::Deserializers::Failure.build(code:, field:))
          end
        end
      end
    end
  end
end
