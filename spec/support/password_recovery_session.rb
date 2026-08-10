# frozen_string_literal: true

module PasswordRecoverySessionSpecHelpers
  # Recovery rate limits are keyed by client IP and bucketed per wall-clock
  # minute, so counters survive across examples unless the db is cleared.
  def flush_password_recovery_rate_limits!
    CommandTower::RedisConnection.with(&:flushdb)
  end

  def create_password_recovery_session!(client_ip: "127.0.0.1")
    post "/auth/password-recovery-session", headers: { "REMOTE_ADDR" => client_ip }
    expect(response).to have_http_status(:created)
    response.parsed_body["data"]
  end

  def password_recovery_session_headers(token, client_ip: "127.0.0.1")
    {
      "Authorization" => "Recovery #{token}",
      "REMOTE_ADDR" => client_ip
    }
  end

  def password_recovery_session_context(jti: SecureRandom.uuid, expires_at: 15.minutes.from_now.utc, client_ip: "127.0.0.1")
    CommandTower::Auth::PasswordRecoverySessionContext.new(jti: jti, expires_at: expires_at, client_ip: client_ip)
  end

  def build_password_recovery_request(path: "/auth/password-reset/send", method: "POST", authorization: nil)
    env = Rack::MockRequest.env_for(path, method: method, "HTTP_AUTHORIZATION" => authorization)
    ActionDispatch::Request.new(env)
  end
end

RSpec.configure do |config|
  config.include PasswordRecoverySessionSpecHelpers
end
