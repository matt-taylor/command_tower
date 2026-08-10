# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Clients
      # Validated response Result contracts for client deserializers.
      # ActiveModel attributes are storage only; validation policy lives in +field+ / +build!+.
      class Result
        include ActiveModel::Model
        include ActiveModel::Attributes

        DEFAULT_UNSET = Object.new.freeze
        private_constant :DEFAULT_UNSET

        class << self
          def field(name, type:, required: false, nullable: false, default: DEFAULT_UNSET)
            name = name.to_sym
            normalized_type = Types.normalize(type)

            if default.equal?(DEFAULT_UNSET)
              has_default = false
              default_value = nil
            else
              validate_default!(default)
              has_default = true
              default_value = default
            end

            field_definitions[name] = {
              type: normalized_type,
              required: required,
              nullable: nullable,
              has_default: has_default,
              default: default_value
            }

            attribute name
          end

          def build!(**attrs)
            values = {}
            field_definitions.each do |name, meta|
              raw = attrs.key?(name) ? attrs[name] : Missing
              values[name] = resolve_field(name, meta, raw)
            end

            new(**values)
          end

          def field_definitions
            @field_definitions ||= {}
          end

          private

          def inherited(subclass)
            super
            subclass.instance_variable_set(:@field_definitions, field_definitions.dup)
          end

          def validate_default!(default)
            return if default.is_a?(Proc)
            return unless shared_mutable_default?(default)

            raise ::CommandTower::Clients::Errors::ConfigurationError,
                  "mutable field defaults must be a Proc (got: #{default.class})"
          end

          def shared_mutable_default?(value)
            value.is_a?(Array) || value.is_a?(Hash)
          end

          def resolve_field(name, meta, raw)
            path = name.to_s

            if raw.equal?(Missing)
              return fail_field!(path, "required", "required field is missing") if meta[:required]
              return materialize_default(meta[:default]) if meta[:has_default]

              return nil
            end

            if raw.nil?
              return nil if meta[:nullable]

              return fail_field!(
                path,
                "nullable",
                "field is not nullable",
                actual: "NilClass"
              )
            end

            meta[:type].call(raw, path: path)
          end

          def materialize_default(default)
            default.is_a?(Proc) ? default.call : default
          end

          def fail_field!(path, rule, message, actual: "Missing")
            raise ::CommandTower::Clients::Errors::DeserializationError.new(
              message: message,
              details: {
                path: path,
                expected: rule == "required" ? "present" : "non-nil",
                actual: actual,
                rule: rule,
                messages: [ message ]
              }
            )
          end
        end

        def ==(other)
          other.instance_of?(self.class) && attributes == other.attributes
        end
        alias eql? ==
      end
    end
  end
end
