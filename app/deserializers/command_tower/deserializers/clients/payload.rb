# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Clients
      # Payload key extraction that distinguishes absent keys from explicit nil.
      module Payload
        module_function

        def fetch(payload, key)
          unless payload.is_a?(Hash)
            raise ::CommandTower::Clients::Errors::ConfigurationError,
                  "Deserializers::Clients::Payload.fetch expects a Hash payload"
          end

          payload.fetch(key, Missing)
        end
      end
    end
  end
end
