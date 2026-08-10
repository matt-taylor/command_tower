# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Product gate for Pushover-dependent Me/Account endpoint lifecycle HTTP.
      # Matches host Capabilities::Pushover.enabled? (pushover_configured?).
      # Does not invent route constraints — callers return 503 when disabled.
      module PushoverProductGate
        module_function

        def enabled?
          CommandTower::Messaging::ChannelDetectors.pushover_configured?
        end
      end
    end
  end
end
