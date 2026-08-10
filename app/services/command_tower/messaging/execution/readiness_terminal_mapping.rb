# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module ReadinessTerminalMapping
        module_function

        def error_code_for(reason_codes)
          codes = Array(reason_codes).map(&:to_s)
          return "recipient_missing" if codes.empty?

          case codes.first
          when RecipientReadiness::ReasonCodes::PLATFORM_DISABLED
            "platform_disabled"
          when RecipientReadiness::ReasonCodes::PLATFORM_UNCONFIGURED
            "adapter_unconfigured"
          when RecipientReadiness::ReasonCodes::IDENTITY_UNVERIFIED
            "recipient_unverified"
          when RecipientReadiness::ReasonCodes::IDENTITY_MISSING,
               RecipientReadiness::ReasonCodes::IDENTITY_UNAVAILABLE
            "recipient_missing"
          when RecipientReadiness::ReasonCodes::ENDPOINT_INVALID
            "invalid_recipient"
          when RecipientReadiness::ReasonCodes::ENDPOINT_MISSING,
               RecipientReadiness::ReasonCodes::ENDPOINT_INACTIVE,
               RecipientReadiness::ReasonCodes::ENDPOINT_UNVERIFIED,
               RecipientReadiness::ReasonCodes::CREDENTIALS_MISSING
            "recipient_missing"
          else
            "recipient_missing"
          end
        end
      end
    end
  end
end
