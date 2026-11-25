# frozen_string_literal: true

module AuthRequestSpecHelpers
  def build_auth_rack_request(path:, method: "GET", headers: {}, cookies: {})
    env = Rack::MockRequest.env_for(
      path,
      method: method,
      "HTTP_AUTHORIZATION" => headers[:authorization],
      "HTTP_COOKIE" => cookies.map { |key, value| "#{key}=#{value}" }.join("; ")
    )
    ActionDispatch::Request.new(env)
  end

  def auth_request_context(path: "/auth/logout", method: "GET", headers: {}, cookies: {})
    request = build_auth_rack_request(path: path, method: method, headers: headers, cookies: cookies)
    CommandTower::Auth::RequestContext.from(request, ActionDispatch::Response.new)
  end

  def login_token_for(user, impersonation_session_id: nil)
    device_session = CommandTower::Services::Auth::DeviceSessions::Start.call(user:).data[:device_session]
    CommandTower::Jwt::LoginCreate.call(user:, impersonation_session_id:, device_session:).token
  end

  def impersonation_token_for(actor, session)
    login_token_for(actor, impersonation_session_id: session.id)
  end

  def authenticate_impersonation_with_bearer!(actor, session)
    { "Authorization" => "Bearer #{impersonation_token_for(actor, session)}" }
  end

  # Request-spec auth setup. Do not POST the login route for setup unless the
  # example under test is login itself.
  def authenticate_request_with_bearer!(user)
    { "Authorization" => "Bearer #{login_token_for(user)}" }
  end

  # Request-spec cookie auth setup. Do not POST the login route for setup unless
  # the example under test is login itself. Prefer bearer helpers for most
  # authenticated request contracts; use this when the example needs cookie
  # presence (e.g. logout cookie clear).
  def authenticate_request_with_cookie!(user)
    cookies[CommandTower.config.jwt.cookie.name] = login_token_for(user)
  end

  # POSTs the plain-text login route. For examples whose subject is login itself.
  def post_plain_text_login(user, headers: {})
    post "/auth/plain-text/login",
         params: { identifier: user.username, password: user.password }, headers: headers, as: :json
  end

  def response_error_code
    response.parsed_body.dig("errors", 0, "code")
  end
end

RSpec.configure do |config|
  config.include AuthRequestSpecHelpers
end
