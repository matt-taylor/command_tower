# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Product gate for Expo push Me/Account endpoint lifecycle HTTP.
      # Matches ChannelDetectors.configured?("push") / expo_configured?.
      # Does not invent route constraints — callers return 503 when disabled.
      module PushProductGate
        module_function

        def enabled?
          CommandTower::Messaging::ChannelDetectors.configured?("push")
        end
      end
    end
  end
end
