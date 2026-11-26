# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class IdentityPolicy < CommandTower::Services::ApplicationService
        # Both verification code generators are numeric-only; the platform exposes the
        # character set so clients can build the right input without guessing.
        NUMERIC_CHARACTER_SET = "numeric"

        # bcrypt ignores input past 72 bytes, and has_secure_password rejects it, so the
        # password max_length rule counts characters and UTF-8 bytes together.
        PASSWORD_MAX_BYTES = 72

        CLIENT = "client"
        SERVER = "server"

        def call
          plain_text = CommandTower.config.login.plain_text
          username = CommandTower.config.username
          email_verify = plain_text.email_verify

          context.policy = {
            password: password_policy(plain_text),
            email: email_policy(plain_text),
            username: username_policy(username),
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

        def password_policy(plain_text)
          min = plain_text.password_length_min
          max = plain_text.password_length_max

          {
            min_length: min,
            max_length: max,
            max_bytes: PASSWORD_MAX_BYTES,
            password_rules: "minlength: #{min}; maxlength: #{max};",
            rules: [
              rule("min_length", "At least #{min} characters", CLIENT),
              rule("max_length", "At most #{max} characters (#{PASSWORD_MAX_BYTES} bytes)", CLIENT),
              rule("not_common", "Not a commonly used password", SERVER),
              rule("not_identifier", "Different from your email", CLIENT)
            ]
          }
        end

        def email_policy(plain_text)
          min = plain_text.email_length_min
          max = plain_text.email_length_max

          {
            min_length: min,
            max_length: max,
            rules: [
              rule("format", "A valid email address", CLIENT),
              rule("length", "Between #{min} and #{max} characters", CLIENT)
            ]
          }
        end

        def username_policy(username)
          min = username.username_length_min
          max = username.username_length_max

          {
            min_length: min,
            max_length: max,
            pattern: javascript_regex_source(username.username_regex.source),
            pattern_description: username.username_failure_message,
            rules: [
              rule("format", username.username_failure_message, CLIENT),
              rule("min_length", "At least #{min} characters", CLIENT),
              rule("max_length", "At most #{max} characters", CLIENT),
              rule("available", "Not already taken", SERVER)
            ],
            self_service: username.self_service,
            self_change: username.self_change,
            prompt: username.prompt
          }
        end

        def rule(id, label, check)
          { id: id, label: label, check: check }
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
