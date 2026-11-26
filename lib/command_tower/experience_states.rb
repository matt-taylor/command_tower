# frozen_string_literal: true

module CommandTower
  # Host-owned registry of the experience keys a host allows users to complete
  # (`POST /me/experience-states/complete`). A key is only accepted when the host
  # registered it, together with the scope types it may be completed under.
  module ExperienceStates
    class Error < CommandTower::Error; end

    class DuplicateKeyError < Error; end
    class InvalidKeyError < Error; end
    class InvalidDefinitionError < Error; end
    class UnregisteredKeyError < Error; end
    class FrozenRegistryError < Error; end
    class EmptyRegistryError < Error; end
  end
end
