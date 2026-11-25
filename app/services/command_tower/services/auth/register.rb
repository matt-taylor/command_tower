# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class Register < CommandTower::Services::ApplicationService
        EMAIL_TAKEN_FRAGMENT = "already been taken"

        EMAIL_TAKEN_MESSAGE = "You already have an account with this email. Sign in or reset your password."
        RULE_IDS = { too_short: "min_length", too_long: "max_length", blocklisted: "not_common" }.freeze

        validate :first_name, is_a: String
        validate :last_name, is_a: String
        validate :username, is_a: String
        validate :email, is_a: String, required: true, sensitive: true
        validate :password, is_a: String, required: true, sensitive: true
        validate :password_confirmation, is_a: String, sensitive: true

        def call
          errors = credential_errors
          reject!(errors) if errors.any?

          user = User.new(
            first_name: first_name.to_s,
            last_name: last_name.to_s,
            username: username.presence,
            email:,
            password:,
            password_confirmation: password_confirmation.presence
          )

          reject!(persistence_errors(user)) unless user.save

          context.user = user
        end

        private

        def plain_text_config
          CommandTower.config.login.plain_text
        end

        def credential_errors
          config = plain_text_config
          errors = {}

          unless email.length.between?(config.email_length_min, config.email_length_max)
            errors[:email] = "Email length must be between #{config.email_length_min} and #{config.email_length_max} characters"
          end

          check = CommandTower::Services::Auth::PasswordPolicy::Check.call(password:)
          unless check.data[:valid]
            errors[:password] = CommandTower::Services::Auth::PasswordPolicy::Check.message_for(check.data[:failures])
            errors[:passwordRulesFailed] = check.data[:failures].filter_map { RULE_IDS[_1] }
          end

          errors[:email] ||= "Invalid email address" unless email =~ URI::MailTo::EMAIL_REGEXP

          if username.present? && !CommandTower::Username::Available.(username:).valid?
            errors[:username] = "Username is invalid. #{CommandTower.config.username.username_failure_message}"
          end

          errors
        end

        def persistence_errors(user)
          user.errors.to_hash.transform_values { Array(_1).join(", ") }
        end

        def reject!(details)
          if details[:email].to_s.downcase.include?(EMAIL_TAKEN_FRAGMENT)
            details = details.merge(email: EMAIL_TAKEN_MESSAGE)
            context.fail!(
              application_error: CommandTower::Errors::Auth::EmailAlreadyRegisteredError.new(details:)
            )
          end

          context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
        end
      end
    end
  end
end
