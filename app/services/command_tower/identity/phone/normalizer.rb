# frozen_string_literal: true

require "phonelib"

module CommandTower
  module Identity
    module Phone
      # Canonical E.164 normalize/reject entry point for Identity phone numbers.
      class Normalizer
        DEFAULT_COUNTRY = "US"

        BLANK_MESSAGE = "is required"
        INVALID_MESSAGE = "is invalid"

        Normalized = Data.define(:normalized, :message) do
          def success? = message.nil?

          def failure? = !success?
        end

        def self.call(phone_number:)
          raw = phone_number.to_s.strip
          return failure(BLANK_MESSAGE) if raw.blank?

          parsed = Phonelib.parse(raw, DEFAULT_COUNTRY)
          return failure(INVALID_MESSAGE) unless parsed.valid?

          e164 = parsed.e164.to_s
          return failure(INVALID_MESSAGE) if e164.blank?

          Normalized.new(normalized: e164, message: nil)
        end

        def self.failure(message)
          Normalized.new(normalized: nil, message:)
        end
        private_class_method :failure
      end
    end
  end
end
