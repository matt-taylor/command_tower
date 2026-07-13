# frozen_string_literal: true

module CommandTower
  module Configuration
    module Login
      module Strategy
        module PlainText
          class PasswordReset < ::CommandTower::Configuration::Base
            include ClassComposer::Generator

            add_composer :enabled,
              desc: "Password reset feature allows users to request password reset via email. By default this is enabled",
              allowed: [FalseClass, TrueClass],
              default: true

            add_composer :token_valid_for,
              desc: "When the password reset token is sent, how long will that token be valid for. By default, this is set to 1 hour",
              allowed: ActiveSupport::Duration,
              default: 10.minutes,
              validator: -> (val) { val < 24.hours },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than #{24.hours}" }

            add_composer :token_length,
              desc: "The length of the password reset token sent via email.",
              allowed: Integer,
              default: 32,
              validator: -> (val) { (val <= 64) && (val >= 16) },
              invalid_message: ->(val) { "Provided #{val}. Value must be less than or equal to 64 and greater than or equal to 16." }

            add_composer :custom_template_name,
              desc: "Custom template name to use for the password reset email. Allows using a different view template without creating a custom mailer class. The template should be located at app/views/command_tower/password_reset_mailer/{template_name}.html.erb. Defaults to 'reset_password'",
              allowed: [String, NilClass],
              default: nil

            add_composer :require_email,
              desc: "When enabled, requires users to provide both token and email when validating or resetting password. This adds an additional security layer to prevent brute force attacks. Defaults to false for backward compatibility.",
              allowed: [FalseClass, TrueClass],
              default: false

            add_composer :reset_password_path,
              desc: "The path (not full URL) to the frontend reset password page. This path will be appended to CommandTower.config.app.composed_url to form the full URL. Used in email template for the reset link. Defaults to '/reset-password'",
              allowed: String,
              default: "/reset-password"
          end
        end
      end
    end
  end
end
