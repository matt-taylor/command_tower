# frozen_string_literal: true

module CommandTower
  module PrincipalCapabilities
    class Error < CommandTower::Error; end

    class UnregisteredCapabilityError < Error; end
    class DuplicateCapabilityError < Error; end
    class HostOverrideError < Error; end
    class InvalidCapabilityNameError < Error; end
    class InvalidCapabilityDefinitionError < Error; end
    class MissingRequiredEntityError < Error; end
    class FrozenRegistryError < Error; end
  end
end
