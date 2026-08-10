# frozen_string_literal: true

module CommandTower
  module Errors
    module Account
      class SmsCapabilityUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "sms_capability_unavailable"
        end

        def message
          "SMS is currently unavailable"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
