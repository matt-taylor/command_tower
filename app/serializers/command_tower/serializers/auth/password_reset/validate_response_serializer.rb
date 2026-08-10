# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      module PasswordReset
        class ValidateResponseSerializer
          def self.serialize(valid:, expires_at:)
            payload = { valid: valid }

            if expires_at.present?
              expires_at_value = expires_at.is_a?(Time) || expires_at.is_a?(DateTime) ? expires_at.iso8601 : expires_at.to_s
              payload[:expiresAt] = expires_at_value
            end

            payload
          end
        end
      end
    end
  end
end
