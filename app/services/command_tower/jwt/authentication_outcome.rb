# frozen_string_literal: true

module CommandTower::Jwt
  # Narrow value object describing the result of AuthenticateUser only.
  # This is deliberately not a platform result type — do not reuse it elsewhere.
  class AuthenticationOutcome
    attr_reader :user, :expires_at, :generated_token, :status, :msg

    def self.success(user:, expires_at:, generated_token: nil)
      new(success: true, user:, expires_at:, generated_token:)
    end

    # `user` is carried on failures so callers can distinguish a known user who
    # is blocked (e.g. email verification required) from an unidentified caller.
    def self.failure(msg:, status: nil, user: nil)
      new(success: false, msg:, status:, user:)
    end

    def initialize(success:, user: nil, expires_at: nil, generated_token: nil, status: nil, msg: nil)
      @success = success
      @user = user
      @expires_at = expires_at
      @generated_token = generated_token
      @status = status
      @msg = msg
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
