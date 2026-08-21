# frozen_string_literal: true

module CommandTower
  module AdminScope
    class Error < CommandTower::Error; end

    class UnregisteredToolError < Error; end
    class DuplicateRegistrationError < Error; end
    class InvalidToolRegistrationError < Error; end
    class MissingRegistrationError < Error; end
    class FrozenRegistryError < Error; end
  end
end

require "command_tower/admin_scope/scope_context"
require "command_tower/admin_scope/scope_option"
require "command_tower/admin_scope/resolve"
require "command_tower/admin_scope/apply_users_narrowing"
require "command_tower/admin_scope/apply_audit_scoping"
require "command_tower/admin_scope/manifest_projection"
