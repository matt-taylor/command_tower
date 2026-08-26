# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/base"

module CommandTower
  module Configuration
    module AccountDeletion
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :host_finalizer,
          desc: "Optional host-owned callable invoked synchronously during account deletion " \
                "before the user row is tombstoned. Receives keyword `user:` (non-deleted User). " \
                "Return value is ignored; raise to abort the deletion transaction.",
          allowed: [Proc, NilClass],
          default: nil,
          default_shown: "nil"
      end
    end
  end
end
