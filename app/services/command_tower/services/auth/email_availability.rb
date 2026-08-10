# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class EmailAvailability < CommandTower::Services::ApplicationService
        validate :email, is_a: String, required: true, sensitive: true

        def call
          normalized = email.strip.downcase

          unless valid_format?(normalized)
            context.valid = false
            context.available = false
            context.message = "Enter a valid email address."
            return
          end

          if ::User.exists?(email: normalized)
            context.valid = true
            context.available = false
            context.message = "Email is already registered"
          else
            context.valid = true
            context.available = true
            context.message = "Email is available"
          end
        end

        private

        def valid_format?(normalized)
          return false unless normalized.match?(URI::MailTo::EMAIL_REGEXP)

          plain_text = CommandTower.config.login.plain_text
          length = normalized.length
          length > plain_text.email_length_min && length < plain_text.email_length_max
        end
      end
    end
  end
end
