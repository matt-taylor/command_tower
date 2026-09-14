# frozen_string_literal: true

module CommandTower
  module ClientCompatibility
    class Error < CommandTower::Error; end

    class HostOverrideError < Error; end
    class DuplicateContractError < Error; end
    class DuplicateEntityRequirementError < Error; end
    class DuplicateBindingError < Error; end
    class UnknownClientContractError < Error; end
    class UnboundClientContractError < Error; end
    class UnknownEntityError < Error; end
    class InvalidPlatformError < Error; end
    class InvalidContractIdError < Error; end
    class InvalidEntityNameError < Error; end
    class InvalidVersionError < Error; end
    class InvalidModeError < Error; end
    class ConflictingRequirementError < Error; end
    class NoConfiguredPlatformsError < Error; end
    class FrozenRegistryError < Error; end
  end
end
