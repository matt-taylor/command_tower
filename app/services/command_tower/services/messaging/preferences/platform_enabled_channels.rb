# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Preferences
        # Resolves host-injected platform channel enablement without reverse
        # dependencies. Hosts assign config.messaging.platform_enabled_channels.
        module PlatformEnabledChannels
          module_function

          def call
            resolver = CommandTower.config.messaging.platform_enabled_channels
            Array(resolver.call).map(&:to_s)
          end
        end
      end
    end
  end
end
