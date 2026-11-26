# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      module EmailVerification
        class MessageResponseSerializer
          # resend_available_at (a Time) is only present on code-request responses.
          def self.serialize(message:, resend_available_at: nil)
            payload = { message: message }
            payload[:resendAvailableAt] = resend_available_at.utc.iso8601 if resend_available_at
            payload
          end
        end
      end
    end
  end
end
