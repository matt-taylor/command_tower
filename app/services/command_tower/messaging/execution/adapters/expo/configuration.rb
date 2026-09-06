# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Expo
          # Platform readiness detector for Expo Push delivery.
          # Ready when transport adapter is fake, log, or http — disabled never counts.
          # http does not require access_token (Expo default); Bearer is optional.
          class Configuration
            CONFIGURED_ADAPTERS = %w[fake log http].freeze

            def self.expo_configured?
              new.expo_configured?
            end

            def expo_configured?
              CONFIGURED_ADAPTERS.include?(adapter_name)
            end

            def adapter_name
              CommandTower.config.messaging.expo.adapter.to_s
            end

            def api_base_url
              CommandTower.config.messaging.expo.api_base_url.to_s.strip
            end

            def timeout_seconds
              CommandTower.config.messaging.expo.timeout_seconds
            end

            def access_token
              CommandTower.config.messaging.expo.access_token.to_s.strip
            end
          end
        end
      end
    end
  end
end
