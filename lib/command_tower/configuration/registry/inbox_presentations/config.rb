# frozen_string_literal: true

require "command_tower/inbox_presentations"
require "command_tower/configuration/registry/inbox_presentations/presentation_definition"

module CommandTower
  module Configuration
    module Registry
      module InboxPresentations
        # No CommandTower-owned presentations are seeded — no PLATFORM_*
        # constant, unlike AdminWorkspace/PrincipalCapabilities. Every
        # registered key today is host-owned (Rich Messaging Slice 2.5).
        class Config
          KEY_FORMAT = /\A[a-z][a-z0-9]*(?:[._][a-z][a-z0-9]*)*\z/

          def initialize
            @definitions = {}
            @finalized = false
          end

          def presentation(key, owner: :host)
            if @finalized
              raise CommandTower::InboxPresentations::FrozenRegistryError,
                "inbox presentations registry is frozen"
            end

            normalized = normalize_key!(key)
            if @definitions.key?(normalized)
              raise CommandTower::InboxPresentations::DuplicateCapabilityError,
                "inbox presentation #{normalized} is already registered"
            end

            definition = PresentationDefinition.new
            yield definition if block_given?
            definition.owner = owner
            definition.validate_definition!(key: normalized)
            @definitions[normalized] = definition
            definition
          end

          def fetch(key)
            normalized = normalize_key!(key)
            definition = @definitions[normalized]
            if definition.nil?
              raise CommandTower::InboxPresentations::UnregisteredCapabilityError,
                "inbox presentation #{normalized} is not registered"
            end

            definition
          end

          def registered?(key)
            @definitions.key?(normalize_key!(key))
          rescue CommandTower::InboxPresentations::InvalidKeyError
            false
          end

          def definitions
            @definitions.dup.freeze
          end

          def finalize!
            @definitions.each_value do |definition|
              next unless definition.respond_to?(:class_composer_freeze_objects!)

              definition.class_composer_freeze_objects!(behavior: :raise, children: true)
            end
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

          def thaw_for_test!
            return unless @finalized || @definitions.frozen?

            @definitions = @definitions.dup
            @finalized = false
          end

          def normalize_key!(key)
            token = key.to_s.strip
            unless token.match?(KEY_FORMAT)
              raise CommandTower::InboxPresentations::InvalidKeyError,
                "invalid inbox presentation key #{key.inspect}"
            end

            token
          end
        end
      end
    end
  end
end
