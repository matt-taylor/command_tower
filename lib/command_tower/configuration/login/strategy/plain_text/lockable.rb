# frozen_string_literal: true

module CommandTower
  module Configuration
    module Login
      module Strategy
        module PlainText
          # DEPRECATED no-op. Nothing reads these settings: password login is protected
          # by `login.rate_limits` (per-IP ceiling and soft per-account lockout, always
          # on unless a limit is set to 0). Setting `enable` to true logs a deprecation.
          class Locakable < ::CommandTower::Configuration::Base
            include ClassComposer::Generator

            DEPRECATION_MESSAGE = "[DEPRECATION] login.plain_text.lockable is a no-op and will be removed; use login.rate_limits instead."

            def self.warn_deprecated
              logger = defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil
              logger ? logger.warn(DEPRECATION_MESSAGE) : Kernel.warn(DEPRECATION_MESSAGE)
            end

            add_composer :enable,
              desc: "DEPRECATED no-op. Use login.rate_limits. Previously enabled extra brute force protection.",
              allowed: [FalseClass, TrueClass],
              default: false,
              validator: ->(val) { !val || warn_deprecated || true },
              invalid_message: ->(val) { "Invalid lockable enable: #{val}" }

            add_composer :password_attempts,
              desc: "Max failed password attempts before additional verification on account is required.",
              allowed: Integer,
              default: 10,
              validator: -> (val) { val >= 0 && val < 50 },
              invalid_message: ->(val) { "Max password attempts must be >=0 and less than 50. Received #{val}" }
          end
        end
      end
    end
  end
end
