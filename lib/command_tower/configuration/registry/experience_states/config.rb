# frozen_string_literal: true

require "class_composer"
require "command_tower/experience_states"
require "command_tower/configuration/registry/experience_states/key_definition"

module CommandTower
  module Configuration
    module Registry
      module ExperienceStates
        # No CommandTower-owned keys are seeded. Every registered key is host-owned.
        class Config
          include ClassComposer::Generator

          MAX_KEY_LENGTH = 128

          add_composer :max_rows_per_user,
                       desc: "Soft cap on completed experience-state rows per user and host_key",
                       allowed: Integer,
                       default: 250

          add_composer :complete_rate,
                       desc: "Per-user rate limit for the complete endpoint: `limit` requests per `window` seconds",
                       allowed: Hash,
                       default: { limit: 30, window: 60 }

          def initialize(*)
            super
            @definitions = {}
            @finalized = false
          end

          def register(key, scope_types:, owner: :host)
            normalized = normalize_key!(key)
            ensure_registrable!(normalized)

            @definitions[normalized] = KeyDefinition.new(
              key: normalized,
              scope_types: normalize_scope_types!(scope_types, key: normalized),
              owner: owner.to_sym
            )
          end

          def fetch(key)
            definition = @definitions[key.to_s]
            if definition.nil?
              raise CommandTower::ExperienceStates::UnregisteredKeyError,
                    "experience state is not registered"
            end

            definition
          end

          def registered?(key)
            @definitions.key?(key.to_s)
          end

          def definitions
            @definitions.dup.freeze
          end

          delegate :empty?, to: :@definitions

          # Boot check: a host with a `host_key` and no registered keys would reject every
          # completion. Raises in the test environment; logs elsewhere so a boot is never blocked.
          def validate_registered!(host_key:, env: Rails.env)
            return if host_key.to_s.strip.empty? || !empty?

            message = "experience states registry is empty while application.host_key is set; " \
                      "register keys with config.registry.experience_states.register"
            raise CommandTower::ExperienceStates::EmptyRegistryError, message if env.to_s == "test"

            Rails.logger.error(message)
          end

          def finalize!
            @definitions.freeze
            @finalized = true
            self
          end

          def finalized?
            @finalized
          end

          def reset_host_definitions!
            thaw_for_test!
            @definitions.delete_if { |_key, definition| definition.owner == :host }
            self
          end

          private

          def ensure_registrable!(normalized)
            if @finalized
              raise CommandTower::ExperienceStates::FrozenRegistryError,
                    "experience states registry is frozen"
            end
            return unless @definitions.key?(normalized)

            raise CommandTower::ExperienceStates::DuplicateKeyError,
                  "experience state #{normalized} is already registered"
          end

          def thaw_for_test!
            return unless @finalized || @definitions.frozen?

            @definitions = @definitions.dup
            @finalized = false
          end

          def normalize_key!(key)
            unless key.is_a?(String) && !key.strip.empty? && key.length <= MAX_KEY_LENGTH
              raise CommandTower::ExperienceStates::InvalidKeyError,
                    "experience state key must be a non-blank string of at most #{MAX_KEY_LENGTH} characters"
            end

            key
          end

          def normalize_scope_types!(scope_types, key:)
            types = Array(scope_types).map { |type| type.to_s.strip }
            if types.empty? || types.any? { |type| type.empty? || type.length > MAX_KEY_LENGTH }
              raise CommandTower::ExperienceStates::InvalidDefinitionError,
                    "experience state #{key} requires at least one valid scope type"
            end

            types.uniq.freeze
          end
        end
      end
    end
  end
end
