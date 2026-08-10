# frozen_string_literal: true

module CommandTower
  module CredentialResolution
    # Applies resolved SMTP credentials into ActionMailer smtp_settings.
    # Delivery contract remains ActionMailer; Credential Resolution only supplies secrets.
    module SmtpActionMailerBridge
      module_function

      def apply!
        return unless defined?(Rails) && Rails.respond_to?(:configuration)

        credentials = CredentialResolution.resolve(:smtp)
        return unless credentials.available?

        hash = Rails.configuration.action_mailer.smtp_settings ||= {}
        Rails.configuration.action_mailer.smtp_settings = hash.merge(
          user_name: credentials.user_name,
          password: credentials.password,
        )
      end
    end
  end
end
