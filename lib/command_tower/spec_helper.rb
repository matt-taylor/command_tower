# frozen_string_literal: true

module CommandTower
  module SpecHelper
    def set_jwt_token!(user:, with_reset: false, token: nil)
      if token.nil?
        result = CommandTower::Jwt::LoginCreate.(user:)
        token = result.token
      end

      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer #{token}"
      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_WITH_RESET] = "true" if with_reset
    end

    def unset_jwt_token!
      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = nil
    end

    # Helper method to get login token and cookie value
    # Uses the login service directly to avoid controller double render issues
    # @param user [User] The user to login
    # @param password [String] The user's password
    # @return [Hash] Hash with :token, :cookie_value, and :cookie_header
    def get_login_token_and_cookie(user:, password:)
      # Authenticate user first
      result = CommandTower::LoginStrategy::PlainText::Login.(identifier: user.username, password:)
      raise "Login failed: #{result.msg}" unless result.success?

      token = result.token
      expires_at = CommandTower.config.jwt.ttl.from_now.to_time.to_s
      cookie_name = CommandTower.config.jwt.cookie.name

      # Create a mock response to set cookie
      mock_response = ActionDispatch::TestResponse.new
      CommandTower::Jwt::AuthorizationHelper.set_token(mock_response, token, expires_at: expires_at)
      cookie_header = mock_response.headers["Set-Cookie"]
      cookie_value = cookie_header&.match(/#{cookie_name}=([^;]+)/)&.[](1)

      { token:, cookie_value:, cookie_header: }
    end

    # Helper to set CSRF cookie in request
    def set_csrf_cookie!(token)
      csrf_cookie_name = CommandTower.config.jwt.cookie.csrf.cookie_name
      @request.cookies[csrf_cookie_name] = token
    end

    # Helper to set CSRF header in request
    def set_csrf_header!(token)
      csrf_header_name = CommandTower.config.jwt.cookie.csrf.header_name
      @request.headers[csrf_header_name] = token
    end

    # Helper to extract CSRF cookie from response
    def extract_csrf_cookie(response)
      csrf_cookie_name = CommandTower.config.jwt.cookie.csrf.cookie_name
      set_cookie_header = response.headers["Set-Cookie"]
      return nil unless set_cookie_header

      # Handle both string and array (when multiple cookies are set)
      cookie_headers = set_cookie_header.is_a?(Array) ? set_cookie_header : [set_cookie_header]

      cookie_headers.each do |header|
        match = header.match(/#{csrf_cookie_name}=([^;]+)/)
        return match[1] if match
      end
      nil
    end

    # Helper to get CSRF cookie value from request
    def get_csrf_cookie_value
      csrf_cookie_name = CommandTower.config.jwt.cookie.csrf.cookie_name
      @request.cookies[csrf_cookie_name]
    end
  end
end
