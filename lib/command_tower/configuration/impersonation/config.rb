# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/base"

module CommandTower
  module Configuration
    module Impersonation
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :idle_timeout,
          desc: "Idle lifetime of an impersonation session. Successful qualifying workflow execution may extend this clock. HTTP activity alone does not.",
          allowed: ActiveSupport::Duration,
          default: 10.minutes

        add_composer :absolute_timeout,
          desc: "Absolute maximum lifetime of an impersonation session measured from start. Activity never extends this clock.",
          allowed: ActiveSupport::Duration,
          default: 1.hour

        def validate!
          if idle_timeout.nil? || idle_timeout <= 0
            raise ArgumentError, "config.impersonation.idle_timeout must be a positive duration"
          end
          if absolute_timeout.nil? || absolute_timeout <= 0
            raise ArgumentError, "config.impersonation.absolute_timeout must be a positive duration"
          end
          if idle_timeout >= absolute_timeout
            raise ArgumentError, "config.impersonation.idle_timeout must be less than absolute_timeout"
          end

          self
        end
      end
    end
  end
end
