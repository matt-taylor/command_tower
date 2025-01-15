# frozen_string_literal: true

module ApiEngineBase::Jwt
  class AuthenticateUser < ApiEngineBase::ServiceBase

    validate :token, is_a: String, required: true, sensitive: true
    validate :bypass_email_validation, is_one: [true, false], default: false

    def call
      result = Decode.(token:)

      if result.failure?
        context.fail!(msg: "Unauthorized Access. Invalid Authorization token")
      end
      payload = result.payload

      validate_generated_at!(generated_at: payload[:generated_at])

      user = User.find(payload[:user_id]) rescue nil
      if user.nil?
        log_warn("user_id [#{payload[:user_id]}] was not found. Cannot Continue")
        context.fail!(msg: "Unauthorized Access. Invalid Authorization token")
      end

      if user.verifier_token == payload[:verifier_token]
        context.user = user
      else
        context.fail!(msg: "Unauthorized Access. Token is no longer valid")
      end

      email_validation_required!(user:)
    end

    def validate_generated_at!(generated_at:)
      if generated_at.nil?
        log_warn("generated_at payload is missing from the JWT token. Cannot continue")
        context.fail!(msg: "Unauthorized Access. Invalid Authorization token")
      end

      expires_time = begin
        time = Time.at(generated_at)
        time + ApiEngineBase.config.jwt.ttl
      rescue
        nil
      end

      if expires_time.nil?
        log_warn("generated_at payload cannot be parsed. Cannot continue")
        context.fail!(msg: "Unauthorized Access. Invalid Authorization token")
      end

      if expires_time < Time.now
        log_warn("generated_at is no longer valid. Must request new token")
        context.fail!(msg: "Unauthorized Access. Invalid Authorization token")
      end
    end

    def email_validation_required!(user:)
      return unless ApiEngineBase.config.login.plain_text.email_verify?

      if bypass_email_validation
        log_info("Bypassing email validation without checking if user should be able to continue")
        return
      end

      return if user.email_validated

      log_info("User's email is not yet validated.")
      result = ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Required.(user:)

      if result.required
        context.fail!(msg: "User's Email must be validated before they can continue")
      end
    end
  end
end
