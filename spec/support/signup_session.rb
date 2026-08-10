# frozen_string_literal: true

module SignupSessionSpecHelpers
  # Signup rate limits are keyed by client IP and bucketed per wall-clock minute,
  # so counters survive across examples unless the db is cleared.
  def flush_signup_rate_limits!
    CommandTower::RedisConnection.with(&:flushdb)
  end

  def create_signup_session!(client_ip: "127.0.0.1")
    post "/auth/signup-session", headers: { "REMOTE_ADDR" => client_ip }
    expect(response).to have_http_status(:created)
    response.parsed_body["data"]
  end

  def signup_session_headers(token)
    { "Authorization" => "Signup #{token}" }
  end

  def signup_session_context(jti: SecureRandom.uuid, expires_at: 20.minutes.from_now.utc, client_ip: "127.0.0.1")
    CommandTower::Auth::SignupSessionContext.new(jti: jti, expires_at: expires_at, client_ip: client_ip)
  end

  def build_signup_request(path: "/auth/email/availability", method: "GET", authorization: nil)
    env = Rack::MockRequest.env_for(path, method: method, "HTTP_AUTHORIZATION" => authorization)
    ActionDispatch::Request.new(env)
  end
end

RSpec.configure do |config|
  config.include SignupSessionSpecHelpers
end
