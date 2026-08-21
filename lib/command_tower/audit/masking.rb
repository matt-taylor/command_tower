# frozen_string_literal: true

module CommandTower
  module Audit
    module Masking
      REDACTED = "********"

      module_function

      def value(field:, raw:)
        return if raw.nil?
        return REDACTED unless scalar?(raw)

        string = raw.to_s
        case field.to_s
        when "phone" then phone(string)
        when "email" then email(string)
        else REDACTED
        end
      end

      def phone(string)
        digits = string.gsub(/\D/, "")
        return REDACTED if digits.length < 4

        "#{'*' * 7}#{digits[-4, 4]}"
      end

      def email(string)
        local, domain = string.split("@", 2)
        return REDACTED if local.blank? || domain.blank?

        "#{local[0]}***@#{domain}"
      end

      def scalar?(raw)
        raw.is_a?(String) || raw.is_a?(Numeric)
      end
    end
  end
end
