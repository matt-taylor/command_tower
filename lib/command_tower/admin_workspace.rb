# frozen_string_literal: true

module CommandTower
  module AdminWorkspace
    class Error < CommandTower::Error; end

    class UnregisteredToolError < Error; end
    class DuplicateToolError < Error; end
    class HostOverrideError < Error; end
    class InvalidToolNameError < Error; end
    class InvalidToolDefinitionError < Error; end
    class DuplicateRouteError < Error; end
    class MissingRequiredEntityError < Error; end
    class FrozenRegistryError < Error; end
  end
end
