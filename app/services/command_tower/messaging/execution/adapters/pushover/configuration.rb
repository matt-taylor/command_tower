# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Pushover
          # Platform readiness detector for Pushover delivery.
          # User-owned credentials (no host app token). Ready when transport adapter
          # is fake, log, or http — disabled never counts as platform_configured.
          class Configuration
            CONFIGURED_ADAPTERS = %w[fake log http].freeze

            def self.pushover_configured?
              new.pushover_configured?
            end

            def pushover_configured?
              CONFIGURED_ADAPTERS.include?(adapter_name)
            end

            def adapter_name
              CommandTower.config.messaging.pushover.adapter.to_s
            end
          end
        end
      end
    end
  end
end
