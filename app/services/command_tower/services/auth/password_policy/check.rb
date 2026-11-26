# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordPolicy
        # Evaluates a candidate password against the configured policy: inclusive length
        # bounds and the common-password blocklist. Never fails the context; callers read
        # `valid` and `failures` (symbols: :too_short, :too_long, :blocklisted).
        class Check < CommandTower::Services::ApplicationService
          validate :password, is_a: String, required: true, sensitive: true

          # Single user-facing message for a failed check, shared by register, reset and change-password.
          def self.message_for(failures)
            plain_text = CommandTower.config.login.plain_text

            if failures.include?(:too_short) || failures.include?(:too_long)
              "Password length must be between #{plain_text.password_length_min} " \
                "and #{plain_text.password_length_max} characters"
            else
              "Password is too common. Choose a less guessable password"
            end
          end

          def call
            context.failures = failures
            context.valid = context.failures.empty?
          end

          private

          def failures
            plain_text = CommandTower.config.login.plain_text

            [
              (:too_short if password.length < plain_text.password_length_min),
              (:too_long if password.length > plain_text.password_length_max),
              (:blocklisted if CommandTower::PasswordPolicy::Blocklist.include?(password))
            ].compact
          end
        end
      end
    end
  end
end
