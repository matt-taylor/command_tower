# frozen_string_literal: true

module CommandTower::Jwt
  class AuthenticateUser # rubocop:disable Metrics/ClassLength
    INVALID_TOKEN_MSG = "Unauthorized Access. Invalid Authorization token"
    STALE_TOKEN_MSG = "Unauthorized Access. Token is no longer valid"
    SESSION_EXPIRED_MSG = "Unauthorized Access. Session has expired"
    SESSION_REVOKED_MSG = "Unauthorized Access. Session is no longer valid"
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
      sid = payload[:sid].presence

      sid ? authenticate_session_token(payload, sid) : authenticate_legacy_token(payload)
    end

    private

    attr_reader :token, :bypass_email_validation, :with_reset

    # Tokens minted with a device session: the session row is the source of truth
    # for lifetime. `jwt.ttl` is not applied, so a session token outlives 7 days.
    def authenticate_session_token(payload, sid)
      device_session = CommandTower::Auth::DeviceSession.includes(:user).find_by(public_id: sid.to_s)
      failure = session_failure(device_session, payload)
      return failure if failure

      user = device_session.user
      failure = user_failure(user, payload)
      return failure if failure

      touch_last_seen(device_session)

      generated_token = nil
      impersonation_session_id = payload[:impersonation_session_id].presence
      if with_reset
        generated_token = LoginCreate.(user:, impersonation_session_id:, device_session:).token
      end

      AuthenticationOutcome.success(
        user:,
        expires_at: session_expires_at(device_session).to_s,
        generated_token:,
        impersonation_session_id:,
        device_session:
      )
    end

    # Sid-less tokens (issued before device sessions): today's rule, generated_at + jwt.ttl.
    def authenticate_legacy_token(payload)
      expires_at = expires_at_for(generated_at: payload[:generated_at])
      return invalid_token if expires_at.nil?

      user = User.find_by(id: payload[:user_id])
      failure = user_failure(user, payload)
      return failure if failure

      return session_revoked if upgraded_row_revoked?(user, payload[:generated_at])

      # Only a valid sid-less token reaches here (expired and rejected ones do not count).
      CommandTower::Services::Auth::RecordLegacyContractUse.call(endpoint: "sidless_token")

      generated_token = nil
      impersonation_session_id = payload[:impersonation_session_id].presence
      if with_reset
        generated_token = LoginCreate.(user:, impersonation_session_id:).token
        expires_at = CommandTower.config.jwt.ttl.from_now.to_time
      end

      AuthenticationOutcome.success(
        user:,
        expires_at: expires_at.to_s,
        generated_token:,
        impersonation_session_id:,
        legacy_generated_at: payload[:generated_at]
      )
    end

    # A legacy token that was already upgraded has a device session row keyed by
    # (user, generated_at). Revoking that row ends the legacy token too.
    def upgraded_row_revoked?(user, generated_at)
      return false unless CommandTower.config.session.enforce

      row = CommandTower::Auth::DeviceSession.find_by(
        user_id: user.id,
        legacy_generated_at: Time.zone.at(generated_at)
      )
      return false unless row&.revoked?

      log_info("legacy token's upgraded device session [#{row.id}] is revoked")
      true
    end

    def session_failure(device_session, payload)
      if device_session.nil?
        log_warn("device session for the presented sid was not found")
        return session_revoked
      end

      if device_session.user_id.to_s != payload[:user_id].to_s
        log_warn("device session [#{device_session.id}] does not belong to the token's user")
        return session_revoked
      end

      now = Time.current
      if now > device_session.absolute_expires_at
        log_info("device session [#{device_session.id}] passed its absolute expiry")
        return session_expired
      end

      # Kill switch: with enforcement off, revoked and idle are skipped; absolute still applies.
      return nil unless CommandTower.config.session.enforce

      if device_session.revoked?
        log_info("device session [#{device_session.id}] is revoked")
        return session_revoked
      end

      if now > device_session.last_seen_at + CommandTower.config.session.idle_timeout
        log_info("device session [#{device_session.id}] passed its idle timeout")
        return session_expired
      end

      nil
    end

    # Checks shared by session and legacy tokens: deleted user, verifier, email gate.
    def user_failure(user, payload)
      if user.nil? || user.deleted?
        log_warn("user_id [#{payload[:user_id]}] was not found. Cannot Continue")
        return invalid_token
      end

      unless user.verifier_token == payload[:verifier_token]
        return AuthenticationOutcome.failure(msg: STALE_TOKEN_MSG, code: AuthenticationOutcome::STALE_TOKEN)
      end

      if email_validation_required?(user:)
        return AuthenticationOutcome.failure(
          msg: EMAIL_VERIFICATION_MSG,
          status: EMAIL_VERIFICATION_STATUS,
          user:,
          code: AuthenticationOutcome::EMAIL_VERIFICATION_REQUIRED
        )
      end

      nil
    end

    # At most one write per session per `last_seen_write_interval`; idle precision is ± that interval.
    def touch_last_seen(device_session)
      now = Time.current
      return if device_session.last_seen_at > now - CommandTower.config.session.last_seen_write_interval

      # Intentional: a throttled heartbeat write must not run validations or bump updated_at.
      device_session.update_columns(last_seen_at: now) # rubocop:disable Rails/SkipsModelValidations
    end

    def session_expires_at(device_session)
      idle_expires_at = device_session.last_seen_at + CommandTower.config.session.idle_timeout
      [idle_expires_at, device_session.absolute_expires_at].min.to_time
    end

    def invalid_token
      AuthenticationOutcome.failure(msg: INVALID_TOKEN_MSG, code: AuthenticationOutcome::INVALID_TOKEN)
    end

    def session_expired
      AuthenticationOutcome.failure(msg: SESSION_EXPIRED_MSG, code: AuthenticationOutcome::SESSION_EXPIRED)
    end

    def session_revoked
      AuthenticationOutcome.failure(msg: SESSION_REVOKED_MSG, code: AuthenticationOutcome::SESSION_REVOKED)
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
