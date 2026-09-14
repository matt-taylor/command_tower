# frozen_string_literal: true

require "command_tower/client_compatibility"
require "command_tower/client_compatibility/version"
require "command_tower/configuration/registry/client_compatibility/platform_definition"
require "command_tower/configuration/registry/client_compatibility/entity_requirement_definition"
require "command_tower/configuration/registry/client_compatibility/binding_definition"
require "command_tower/configuration/registry/client_compatibility/contract_definition"

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # Two-source registry composing platform-global policy, named client
        # contracts, capability-scoped entity requirements, and host bindings.
        # Mirrors the `principal_capabilities` / `admin_workspace` / `audit`
        # registry pattern (CT-owned vs host-owned, `finalize!`/freeze,
        # `reset_host_definitions!` for specs). Authority §5-§9.
        #
        # V1 ships with an empty CommandTower-owned catalog by design: no
        # platform requires any contract or entity requirement out of the box.
        class Config
          PLATFORMS = %i[web ios android].freeze
          MODES = %i[observe enforce].freeze
          CONTRACT_ID = /\A[a-z][a-z0-9_]*(\.[a-z0-9][a-z0-9_]*)*\z/

          # CommandTower-owned seed catalog. Deliberately empty for V1 — see
          # authority §7.5. Do not seed placeholder/fictional contracts here.
          PLATFORM_CONTRACTS = [].freeze
          PLATFORM_ENTITY_REQUIREMENTS = {}.freeze

          attr_reader :mode

          def initialize
            @mode = :observe
            @platforms = {}
            @contracts = {}
            @entity_requirements = {}
            @bindings = {}
            @finalized = false
            seed_platform_catalog!
          end

          def mode=(value)
            raise_if_finalized!
            normalized = value.to_s.to_sym
            unless MODES.include?(normalized)
              raise CommandTower::ClientCompatibility::InvalidModeError,
                "client_compatibility mode must be one of #{MODES.inspect}, got #{value.inspect}"
            end

            @mode = normalized
          end

          def platform(name)
            raise_if_finalized!
            key = normalize_platform!(name)
            definition = @platforms[key] || PlatformDefinition.new
            yield definition if block_given?
            definition.validate_definition!(platform: key)
            @platforms[key] = definition
            definition
          end

          def configured_platforms
            @platforms.keys.dup.freeze
          end

          def platform_policy(name)
            @platforms[name.to_s.strip.downcase.to_sym]
          end

          def client_contract(name, owner: :host)
            raise_if_finalized!
            normalized = normalize_contract_id!(name)
            existing = @contracts[normalized]
            if existing
              if existing.owner == :command_tower && owner.to_sym == :host
                raise CommandTower::ClientCompatibility::HostOverrideError,
                  "host cannot redefine CommandTower-owned client contract #{normalized}"
              end

              raise CommandTower::ClientCompatibility::DuplicateContractError,
                "client contract #{normalized} is already registered"
            end

            definition = ContractDefinition.new
            definition.id = normalized
            definition.owner = owner.to_sym
            @contracts[normalized] = definition
            definition
          end

          def contract_registered?(name)
            @contracts.key?(normalize_contract_id!(name))
          rescue CommandTower::ClientCompatibility::InvalidContractIdError
            false
          end

          def bind(contract_id)
            raise_if_finalized!
            normalized = normalize_contract_id!(contract_id)
            unless @contracts.key?(normalized)
              raise CommandTower::ClientCompatibility::UnknownClientContractError,
                "cannot bind unknown client contract #{normalized}"
            end

            if @bindings.key?(normalized)
              raise CommandTower::ClientCompatibility::DuplicateBindingError,
                "client contract #{normalized} is already bound"
            end

            definition = BindingDefinition.new
            yield definition if block_given?
            definition.validate!(contract_id: normalized)
            @bindings[normalized] = definition
            definition
          end

          def binding_for(contract_id)
            @bindings[normalize_contract_id!(contract_id)]
          rescue CommandTower::ClientCompatibility::InvalidContractIdError
            nil
          end

          def entity(name, owner: :host)
            raise_if_finalized!
            normalized = normalize_entity_name!(name)
            existing = @entity_requirements[normalized]
            if existing
              if existing.owner == :command_tower && owner.to_sym == :host
                raise CommandTower::ClientCompatibility::HostOverrideError,
                  "host cannot redefine CommandTower-owned client compatibility entity requirement #{normalized}"
              end

              raise CommandTower::ClientCompatibility::DuplicateEntityRequirementError,
                "client compatibility entity requirement #{normalized} is already registered"
            end

            definition = EntityRequirementDefinition.new
            yield definition if block_given?
            definition.owner = owner
            definition.validate_definition!(name: normalized)
            @entity_requirements[normalized] = definition
            definition
          end

          def entity_requirement(name)
            @entity_requirements[name.to_s]
          end

          def registered_entity_requirement?(name)
            @entity_requirements.key?(name.to_s)
          end

          # Whether the host has meaningfully engaged this registry at all.
          # A completely untouched registry (no platforms, no host contracts,
          # no host entity requirements, no bindings, default observe mode)
          # is inert: evaluation is a no-op and boot MUST NOT fail on it.
          def opted_in?
            @mode == :enforce ||
              @platforms.any? ||
              @contracts.any? { |_id, definition| definition.owner == :host } ||
              @entity_requirements.any? { |_name, definition| definition.owner == :host } ||
              @bindings.any?
          end

          def finalize!
            (@platforms.values + @entity_requirements.values + @bindings.values).each do |definition|
              next unless definition.respond_to?(:class_composer_freeze_objects!)

              definition.class_composer_freeze_objects!(behavior: :raise, children: true)
            end
            @platforms.freeze
            @contracts.freeze
            @entity_requirements.freeze
            @bindings.freeze
            @finalized = true
            self
          end

          def finalized?
            @finalized
          end

          # Boot-time fail-closed validation (authority §9). No-op unless the
          # host has opted in (see `opted_in?`).
          def validate!(entities)
            return self unless opted_in?

            if @platforms.empty?
              raise CommandTower::ClientCompatibility::NoConfiguredPlatformsError,
                "client_compatibility is configured but declares zero platforms"
            end

            validate_entity_requirements!(entities)
            validate_bindings!
            self
          end

          # Process-level ENV overlays (never the client's own headers).
          # `COMMAND_TOWER_CLIENT_COMPATIBILITY_MODE` may set observe/enforce.
          # `COMMAND_TOWER_CLIENT_COMPATIBILITY_MINIMUM_{WEB,IOS,ANDROID}` may
          # only RAISE an already-configured platform's minimum — never lower
          # it, and never configure a platform the host did not enable.
          def apply_env_overlay!(env: ENV)
            raise_if_finalized!

            overlay_mode = env["COMMAND_TOWER_CLIENT_COMPATIBILITY_MODE"]
            self.mode = overlay_mode if overlay_mode.present?

            PLATFORMS.each { |platform| apply_env_minimum_overlay!(platform, env:) }

            self
          end

          def reset_host_definitions!
            thaw_for_test!
            @platforms = {}
            @contracts.delete_if { |_id, definition| definition.owner == :host }
            @entity_requirements.delete_if { |_name, definition| definition.owner == :host }
            @bindings = {}
            @mode = :observe
            self
          end

          private

          def apply_env_minimum_overlay!(platform, env:)
            raw = env[env_minimum_key(platform)]
            return if raw.blank?

            definition = @platforms[platform]
            return if definition.nil? # ENV cannot configure a platform the host never enabled

            normalized = CommandTower::ClientCompatibility::Version.normalize(raw)
            if normalized.nil?
              raise CommandTower::ClientCompatibility::InvalidVersionError,
                "ENV #{env_minimum_key(platform)} has invalid version #{raw.inspect}"
            end

            definition.minimum = normalized if Gem::Version.new(normalized) > Gem::Version.new(definition.minimum)
          end

          def env_minimum_key(platform)
            "COMMAND_TOWER_CLIENT_COMPATIBILITY_MINIMUM_#{platform.to_s.upcase}"
          end

          def seed_platform_catalog!
            PLATFORM_CONTRACTS.each { |name| client_contract(name, owner: :command_tower) }
            PLATFORM_ENTITY_REQUIREMENTS.each do |name, contract|
              entity(name, owner: :command_tower) { |requirement| requirement.client_contract = contract }
            end
          end

          def validate_entity_requirements!(entities)
            @entity_requirements.each do |name, definition|
              unless entities.key?(name)
                raise CommandTower::ClientCompatibility::UnknownEntityError,
                  "client compatibility entity requirement references unknown RBAC entity #{name}"
              end

              if definition.client_contract.present?
                unless @contracts.key?(definition.client_contract)
                  raise CommandTower::ClientCompatibility::UnknownClientContractError,
                    "entity #{name} requires unknown client contract #{definition.client_contract}"
                end

                next
              end

              validate_direct_minimum_floor!(name:, definition:)
            end
          end

          def validate_direct_minimum_floor!(name:, definition:)
            @platforms.each do |platform, policy|
              direct = definition.minimum.for_platform(platform)
              next if direct.blank?

              if Gem::Version.new(direct) < Gem::Version.new(policy.minimum)
                raise CommandTower::ClientCompatibility::ConflictingRequirementError,
                  "entity #{name} minimum.#{platform} #{direct} is lower than platform-global minimum #{policy.minimum}"
              end
            end
          end

          def validate_bindings!
            referenced_contract_ids.each do |contract_id|
              binding = @bindings[contract_id]
              @platforms.each_key do |platform|
                next if binding && binding.for_platform(platform).present?

                raise CommandTower::ClientCompatibility::UnboundClientContractError,
                  "client contract #{contract_id} has no host binding for configured platform #{platform}"
              end
            end
          end

          def referenced_contract_ids
            @entity_requirements.values.filter_map { |definition| definition.client_contract }.uniq
          end

          def normalize_platform!(name)
            key = name.to_s.strip.downcase.to_sym
            unless PLATFORMS.include?(key)
              raise CommandTower::ClientCompatibility::InvalidPlatformError,
                "unknown canonical platform #{name.inspect}; must be one of #{PLATFORMS.inspect}"
            end

            key
          end

          def normalize_contract_id!(name)
            token = name.to_s.strip
            unless token.match?(CONTRACT_ID)
              raise CommandTower::ClientCompatibility::InvalidContractIdError,
                "invalid client contract id #{name.inspect}"
            end

            token
          end

          def normalize_entity_name!(name)
            token = name.to_s.strip
            unless token.match?(CommandTower::Events::SEGMENT)
              raise CommandTower::ClientCompatibility::InvalidEntityNameError,
                "invalid client compatibility entity name #{name.inspect}"
            end

            token
          end

          def raise_if_finalized!
            return unless @finalized

            raise CommandTower::ClientCompatibility::FrozenRegistryError, "client compatibility registry is frozen"
          end

          def thaw_for_test!
            return unless @finalized

            @platforms = @platforms.dup
            @contracts = @contracts.dup
            @entity_requirements = @entity_requirements.dup
            @bindings = @bindings.dup
            @finalized = false
          end
        end
      end
    end
  end
end
