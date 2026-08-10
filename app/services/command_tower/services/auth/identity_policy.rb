# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class IdentityPolicy < CommandTower::Services::ApplicationService
        # Both verification code generators are numeric-only; the platform exposes the
        # character set so clients can build the right input without guessing.
        NUMERIC_CHARACTER_SET = "numeric"

        def call
          plain_text = CommandTower.config.login.plain_text
          username = CommandTower.config.username
          email_verify = plain_text.email_verify

          context.policy = {
            password: exclusive_length_bounds(
              min: plain_text.password_length_min,
              max: plain_text.password_length_max
            ),
            email: exclusive_length_bounds(
              min: plain_text.email_length_min,
              max: plain_text.email_length_max
            ),
            username: {
              min_length: username.username_length_min,
              max_length: username.username_length_max,
              pattern: javascript_regex_source(username.username_regex.source),
              pattern_description: username.username_failure_message
            },
            verification_code: {
              length: email_verify.verify_code_length,
              character_set: NUMERIC_CHARACTER_SET
            },
            phone_verification_code: {
              length: CommandTower.config.identity.phone_verification.verify_code_length,
              character_set: NUMERIC_CHARACTER_SET
            }
          }
        end

        private

        def exclusive_length_bounds(min:, max:)
          {
            min_length: min + 1,
            max_length: max - 1
          }
        end

        def javascript_regex_source(ruby_source)
          ruby_source
            .gsub("\\A", "^")
            .gsub("\\z", "$")
            .gsub("\\Z", "$")
        end
      end
    end
  end
end
