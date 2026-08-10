# frozen_string_literal: true

module CommandTower::Jwt
  class AuthenticateUser
    INVALID_TOKEN_MSG = "Unauthorized Access. Invalid Authorization token"
    STALE_TOKEN_MSG = "Unauthorized Access. Token is no longer valid"
    EMAIL_VERIFICATION_MSG = "Email must be verified to continue"
    EMAIL_VERIFICATION_STATUS = 412

    def self.call(token:, bypass_email_validation: false, with_reset: false)
      new(token:, bypass_email_validation:, with_reset:).call
    end

    def initialize(token:, bypass_email_validation: false, with_reset: false)
      @token = token
      @bypass_email_validation = !!bypass_email_validation
      @with_reset = !!with_reset
    end

    def call
      decoded = Decode.(token:)
      return invalid_token if decoded.failure?

      payload = decoded.payload

      expires_at = expires_at_for(generated_at: payload[:generated_at])
      return invalid_token if expires_at.nil?

      user = User.find_by(id: payload[:user_id])
      if user.nil?
        log_warn("user_id [#{payload[:user_id]}] was not found. Cannot Continue")
        return invalid_token
      end

      unless user.verifier_token == payload[:verifier_token]
        return AuthenticationOutcome.failure(msg: STALE_TOKEN_MSG)
      end

      if email_validation_required?(user:)
        return AuthenticationOutcome.failure(
          msg: EMAIL_VERIFICATION_MSG,
          status: EMAIL_VERIFICATION_STATUS,
          user:
        )
      end

      generated_token = nil
      if with_reset
        generated_token = LoginCreate.(user:).token
        expires_at = CommandTower.config.jwt.ttl.from_now.to_time
      end

      AuthenticationOutcome.success(user:, expires_at: expires_at.to_s, generated_token:)
    end

    private

    attr_reader :token, :bypass_email_validation, :with_reset

    def invalid_token
      AuthenticationOutcome.failure(msg: INVALID_TOKEN_MSG)
    end

    # Returns nil when the token cannot be trusted to carry a usable expiration.
    def expires_at_for(generated_at:)
      if generated_at.nil?
        log_warn("generated_at payload is missing from the JWT token. Cannot continue")
        return nil
      end

      expires_time = begin
        Time.at(generated_at) + CommandTower.config.jwt.ttl
      rescue StandardError
        nil
      end

      if expires_time.nil?
        log_warn("generated_at payload cannot be parsed. Cannot continue")
        return nil
      end

      if expires_time < Time.now
        log_warn("generated_at is no longer valid. Must request new token")
        return nil
      end

      expires_time
    end

    def email_validation_required?(user:)
      return false unless CommandTower.config.login.plain_text.email_verify?

      if bypass_email_validation
        log_info("Bypassing email validation without checking if user should be able to continue")
        return false
      end

      return false if user.email_validated

      log_info("User's email is not yet validated.")

      CommandTower::LoginStrategy::PlainText::EmailVerification::Required.(user:).required?
    end

    def log_info(msg)
      Rails.logger.info { "[#{self.class.name}] #{msg}" }
    end

    def log_warn(msg)
      Rails.logger.warn { "[#{self.class.name}] #{msg}" }
    end
  end
end
