# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Product gate for SMS-dependent Me/Account phone lifecycle HTTP.
      # Matches Me::Capabilities#sms_enabled? / host Capabilities::Sms.enabled?:
      # Messaging notification SMS configured ∧ Identity OTP SMS ready.
      # Does not invent route constraints — callers return 503 when disabled.
      module SmsProductGate
        module_function

        def enabled?
          CommandTower::Messaging::ChannelDetectors.sms_product_ready?
        end
      end
    end
  end
end
