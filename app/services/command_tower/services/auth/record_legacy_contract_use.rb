# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      # Emits `command_tower.auth.legacy_contract_used` when a client uses part of the auth
      # contract that is deprecated (the signup/recovery sessions, the availability endpoints,
      # the old register shape, or a valid sid-less token). Observation only: it never changes
      # a response. The payload is the endpoint, app version and platform, and nothing else, so
      # no PII reaches the event stream.
      class RecordLegacyContractUse < CommandTower::Services::ApplicationService
        validate :endpoint, is_a: String, required: true

        def call
          CommandTower::Events.publish(
            category: :auth,
            name: "legacy_contract_used",
            payload: {
              endpoint: endpoint,
              app_version: CommandTower::Current.client_app_version,
              platform: CommandTower::Current.client_platform
            }
          )
        end
      end
    end
  end
end
