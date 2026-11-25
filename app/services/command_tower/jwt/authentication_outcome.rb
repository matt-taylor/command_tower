# frozen_string_literal: true

module CommandTower::Jwt
  # Narrow value object describing the result of AuthenticateUser only.
  # This is deliberately not a platform result type — do not reuse it elsewhere.
  class AuthenticationOutcome
    # Failure codes. SESSION_EXPIRED and SESSION_REVOKED are rendered to clients
    # as their own 401 error codes; the others keep today's 401/412 bodies.
    INVALID_TOKEN = "invalid_token"
    STALE_TOKEN = "stale_token"
    EMAIL_VERIFICATION_REQUIRED = "email_verification_required"
    SESSION_EXPIRED = "session_expired"
    SESSION_REVOKED = "session_revoked"
    SESSION_CODES = [SESSION_EXPIRED, SESSION_REVOKED].freeze

    attr_reader :user, :expires_at, :generated_token, :status, :msg, :impersonation_session_id, :code, :device_session

    # `device_session` is nil for legacy (sid-less) tokens.
    def self.success(user:, expires_at:, generated_token: nil, impersonation_session_id: nil, device_session: nil)
      new(success: true, user:, expires_at:, generated_token:, impersonation_session_id:, device_session:)
    end

    # `user` is carried on failures so callers can distinguish a known user who
    # is blocked (e.g. email verification required) from an unidentified caller.
    def self.failure(msg:, status: nil, user: nil, code: nil)
      new(success: false, msg:, status:, user:, code:)
    end

    def initialize(success:, user: nil, expires_at: nil, generated_token: nil, status: nil, msg: nil, impersonation_session_id: nil, code: nil, device_session: nil)
      @success = success
      @user = user
      @expires_at = expires_at
      @generated_token = generated_token
      @status = status
      @msg = msg
      @impersonation_session_id = impersonation_session_id
      @code = code
      @device_session = device_session
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def session_failure?
      SESSION_CODES.include?(code)
    end

    # True for a success on a sid-less token issued before device sessions.
    def legacy_token?
      success? && device_session.nil?
    end
  end
end
