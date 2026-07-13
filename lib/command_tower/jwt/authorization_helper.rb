# frozen_string_literal: true

module CommandTower
  module Jwt
    module AuthorizationHelper
      AUTHENTICATION_HEADER = "Authorization"
      AUTHENTICATION_EXPIRE_HEADER = "X-Authorization-Expire"
      AUTHENTICATION_WITH_RESET = "X-Authorization-Reset"

      module_function

      # Validates and extracts token from Authorization header OR cookie (if enabled)
      # Returns hash with :token and :source on success, or hash with :error and :message on failure
      # @param request [ActionDispatch::Request] The request object
      # @return [Hash] Hash with :token and :source (:header, :cookie) on success, or :error and :message on failure
      def extract_token(request)
        # First try Authorization header
        raw_token = request.headers[AUTHENTICATION_HEADER]
        if raw_token && !raw_token.to_s.strip.empty?
          # Validate Bearer format with strict regex (case-insensitive)
          # Matches: \ABearer\s+(.+)\z
          # - \A: start of string
          # - Bearer: literal "Bearer" (case-insensitive with /i flag)
          # - \s+: one or more whitespace characters
          # - (.+): capture group for token (one or more characters)
          # - \z: end of string
          match = raw_token.match(/\ABearer\s+(.+)\z/i)
          if match && match[1] && !match[1].strip.empty?
            token = match[1].strip
            return { token:, source: :header }
          else
            return { error: :invalid_format, message: "Invalid Bearer token format" }
          end
        end

        # Fallback to cookie if header is missing/empty AND cookie enabled
        if cookie_enabled?
          cookie_token = read_cookie(request)
          return { token: cookie_token, source: :cookie } if cookie_token && !cookie_token.strip.empty?
        end

        # No token found
        { error: :missing, message: "Bearer token missing" }
      end

      # Sets token in response (headers and optionally cookie)
      # @param response [ActionDispatch::Response] The response object
      # @param token [String] The JWT token to set
      # @param expires_at [String, nil] Optional expiration time string
      def set_token(response, token, expires_at: nil)
        # Always set headers
        response.set_header(AUTHENTICATION_WITH_RESET, token)
        response.set_header(AUTHENTICATION_EXPIRE_HEADER, expires_at) if expires_at && !expires_at.to_s.strip.empty?

        # Set cookie if enabled
        set_cookie(response, token) if cookie_enabled?
      end

      # Clears token from response (cookie only, headers are response-only)
      # @param response [ActionDispatch::Response] The response object
      def clear_token(response)
        clear_cookie(response) if cookie_enabled?
        # Clear CSRF cookie on logout
        # Logout always clears CSRF cookie (not configurable - this is the only correct behavior)
        CommandTower::Jwt::CsrfHelper.clear_cookie(response) if CommandTower::Jwt::CsrfHelper.csrf_enabled?
      end

      # Reads cookie value from request
      # @param request [ActionDispatch::Request] The request object
      # @return [String, nil] Cookie value or nil
      def read_cookie(request)
        return nil unless cookie_enabled?

        request.cookies[CommandTower.config.jwt.cookie.name.downcase]
      end

      # Returns consistent cookie options hash (single source of truth)
      # @param expires_at [Time, ActiveSupport::TimeWithZone] Expiration time for the cookie
      # @return [Hash] Cookie options hash with all attributes
      def cookie_options(expires_at:)
        config = CommandTower.config.jwt.cookie
        secure_value = config.secure || Rails.env.production?
        options = {
          expires: expires_at,
          httponly: config.httponly,
          secure: secure_value,
          same_site: config.same_site,
          path: config.path
        }
        options[:domain] = config.domain if config.domain.present?
        options
      end

      # Sets cookie with configured options
      # @param response [ActionDispatch::Response] The response object
      # @param token [String] The JWT token to set
      def set_cookie(response, token)
        return unless cookie_enabled?

        config = CommandTower.config.jwt.cookie
        options = cookie_options(expires_at: config.ttl.from_now)
        options[:value] = token

        response.set_cookie(config.name, options)
      end

      # Clears cookie by setting it to expire in the past
      # @param response [ActionDispatch::Response] The response object
      def clear_cookie(response)
        return unless cookie_enabled?

        config = CommandTower.config.jwt.cookie
        options = cookie_options(expires_at: 1.year.ago)
        options[:value] = ""

        response.set_cookie(config.name, options)
      end

      # Gets the with_reset flag from request headers
      # @param request [ActionDispatch::Request] The request object
      # @return [Boolean, nil] The boolean value or nil
      def get_with_reset_flag(request)
        value = request.headers[AUTHENTICATION_WITH_RESET]
        return nil unless [true, false, "true", "false", "0", "1", 0, 1].include?(value)

        ActiveModel::Type::Boolean.new.cast(value)
      end

      # Checks if cookie auth is enabled
      # @return [Boolean]
      def cookie_enabled?
        CommandTower.config.jwt.cookie.enabled?
      end
    end
  end
end
