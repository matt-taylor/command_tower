# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Login
      # Ceilings for POST /auth/plain-text/login. A value of 0 disables that bucket.
      class RateLimits < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        LOCKOUT_KEY_PURPOSE = "command_tower.login_lockout"

        add_composer :account_failures,
                     desc: "Failed logins per account (or unknown identifier) within account_window_seconds " \
                           "before a soft lock. 0 disables the lockout",
                     allowed: Integer,
                     default: 10,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :account_window_seconds,
                     desc: "Window in which account_failures are counted",
                     allowed: Integer,
                     default: 15 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :lock_base_seconds,
                     desc: "Length of the first soft lock. Doubles each time a lock trips again " \
                           "within lock_level_window_seconds",
                     allowed: Integer,
                     default: 15 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :lock_max_seconds,
                     desc: "Upper bound for a soft lock. Every lock expires",
                     allowed: Integer,
                     default: 60 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :lock_level_window_seconds,
                     desc: "How long repeat locks are remembered when choosing the next lock length",
                     allowed: Integer,
                     default: 24 * 60 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :ip_attempts,
                     desc: "Login attempts per client IP within ip_window_seconds. 0 disables the bucket",
                     allowed: Integer,
                     default: 100,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :ip_window_seconds,
                     desc: "Window for ip_attempts",
                     allowed: Integer,
                     default: 15 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :reset_attempts_per_ip,
                     desc: "Password reset token validate and redeem attempts per client IP within " \
                           "reset_window_seconds. 0 disables the bucket",
                     allowed: Integer,
                     default: 30,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :reset_window_seconds,
                     desc: "Window for reset_attempts_per_ip",
                     allowed: Integer,
                     default: 15 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :register_attempts_per_email,
                     desc: "POST /auth/register attempts per normalized email per hour. 0 disables the bucket",
                     allowed: Integer,
                     default: 5,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :verify_attempts,
                     desc: "Email verification code attempts per user within verify_window_seconds. " \
                           "0 disables the bucket",
                     allowed: Integer,
                     default: 10,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :verify_window_seconds,
                     desc: "Window for verify_attempts",
                     allowed: Integer,
                     default: 15 * 60,
                     validator: ->(val) { val.positive? },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be > 0" }

        add_composer :verify_send_quiet_seconds,
                     desc: "A second verification code request inside this window sends nothing and " \
                           "answers 200 with resendAvailableAt. 0 disables the quiet window",
                     allowed: Integer,
                     default: 60,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        add_composer :verify_send_per_hour,
                     desc: "Verification codes sent per user per hour. 0 disables the cap",
                     allowed: Integer,
                     default: 20,
                     validator: ->(val) { val >= 0 },
                     invalid_message: ->(val) { "Provided #{val.inspect}. Value must be >= 0" }

        # Key for HMAC'ing lockout subjects so no email or username sits in Redis in
        # plaintext. Derived once and memoized: a fresh KeyGenerator runs PBKDF2 per call.
        def lockout_hmac_key
          @lockout_hmac_key ||= Rails.application.key_generator.generate_key(LOCKOUT_KEY_PURPOSE, 32)
        end
      end
    end
  end
end
