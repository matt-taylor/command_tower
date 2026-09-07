# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      module ExperienceStates
        class CompleteDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:experience_key, :scope_type, :scope_identifier, :version)

          MAX_LENGTH = 128

          def call(params)
            experience_key = extract(params, :experienceKey, :experience_key)
            scope_type = extract(params, :scopeType, :scope_type)
            scope_identifier = extract(params, :scopeIdentifier, :scope_identifier)
            version = extract(params, :version, :Version)

            if [experience_key, scope_type, scope_identifier, version].any?(&:blank?)
              return failure(errors: { message: "missing_required_fields" })
            end

            if [experience_key, scope_type, scope_identifier, version].any? { |value| value.length > MAX_LENGTH }
              return failure(errors: { message: "invalid_field_length" })
            end

            success(
              Input.new(
                experience_key:,
                scope_type:,
                scope_identifier:,
                version:,
              ),
            )
          end

          private

          def extract(params, *keys)
            keys.each do |key|
              raw = params[key] || params[key.to_s]
              next if raw.nil?

              value = raw.to_s.strip
              return value unless value.empty?
            end
            ""
          end
        end
      end
    end
  end
end
