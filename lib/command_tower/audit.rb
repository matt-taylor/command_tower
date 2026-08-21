# frozen_string_literal: true

module CommandTower
  module Audit
    class Error < CommandTower::Error; end

    class UnregisteredEventError < Error; end
    class DuplicateEventError < Error; end
    class HostOverrideError < Error; end
    class InvalidEventNameError < Error; end
    class ForbiddenChangeKeyError < Error; end
    class InvalidPayloadError < Error; end
    class InvalidAttributionError < Error; end
    class MissingSubjectError < Error; end
    class MissingAffectedUserError < Error; end
    class FrozenRegistryError < Error; end
    class InvalidEventDefinitionError < Error; end
    class EnablementNotConfigurableError < Error; end
    class ImmutableError < Error; end
  end
end

require "command_tower/audit/payload"
require "command_tower/audit/attribution"
require "command_tower/audit/emit"
require "command_tower/audit/masking"
require "command_tower/audit/persistence/subscriber"
