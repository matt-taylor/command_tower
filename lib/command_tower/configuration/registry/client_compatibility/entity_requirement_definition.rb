# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/registry/client_compatibility/minimum_overrides"

module CommandTower
  module Configuration
    module Registry
      module ClientCompatibility
        # Capability-scoped version requirement bound to an existing RBAC entity.
        # Authority §6. CommandTower-owned entity requirements MUST reference a
        # named `client_contract`; host-owned entity requirements may reference a
        # `client_contract` OR set direct per-platform minima, never both.
        class EntityRequirementDefinition
          include ClassComposer::Generator

          add_composer :client_contract,
            desc: "Named CT-owned client contract this entity requirement is bound to",
            allowed: [String, Symbol, NilClass],
            default: nil

          attr_accessor :owner, :id
          attr_reader :minimum

          def initialize
            @minimum = MinimumOverrides.new
          end

          def validate_definition!(name:)
            @id = name.to_s
            self.owner = owner&.to_sym || :host

            contract_present = client_contract.present?
            direct_present = minimum.any_set?

            if contract_present && direct_present
              raise CommandTower::ClientCompatibility::ConflictingRequirementError,
                "entity requirement #{name} MUST NOT set both client_contract and a direct minimum"
            end

            if owner == :command_tower && !contract_present
              raise CommandTower::ClientCompatibility::ConflictingRequirementError,
                "CommandTower-owned entity requirement #{name} MUST declare a client_contract, not a direct host version"
            end

            self.client_contract = normalize_contract_id!(client_contract, name:) if contract_present
            minimum.validate!(name:) if direct_present

            self
          end

          private

          def normalize_contract_id!(value, name:)
            token = value.to_s.strip
            unless token.match?(CommandTower::Configuration::Registry::ClientCompatibility::Config::CONTRACT_ID)
              raise CommandTower::ClientCompatibility::InvalidContractIdError,
                "entity requirement #{name} has invalid client_contract #{value.inspect}"
            end

            token
          end
        end
      end
    end
  end
end
