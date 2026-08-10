# frozen_string_literal: true

module CommandTower
  module CredentialResolution
    # Default ENV-backed credential source (precedence tier 3).
    # Documented keys only — provider consumers must not call this directly.
    module EnvBackend
      module_function

      def twilio
        TwilioCredentials.new(
          account_sid: ENV["TWILIO_ACCOUNT_SID"],
          auth_token: ENV["TWILIO_AUTH_TOKEN"],
        )
      end

      def smtp
        SmtpCredentials.new(
          user_name: ENV["GMAIL_USER_NAME"],
          password: ENV["GMAIL_PASSWORD"],
        )
      end
    end
  end
end
