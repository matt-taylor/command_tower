# frozen_string_literal: true

require "active_support/security_utils"

module CommandTower
  module Jwt
    module CsrfHelper
      module_function

      # Generate a new CSRF token
      def generate_token
        SecureRandom.hex(32)
      end

      # Set CSRF cookie in response
      def set_cookie(response, token)
        return unless csrf_enabled?

        config = CommandTower.config.jwt.cookie.csrf
        options = csrf_cookie_options(expires_at: config.ttl.from_now)
        options[:value] = token

        response.set_cookie(config.cookie_name, options)
      end

      # Clear CSRF cookie
      def clear_cookie(response)
        return unless csrf_enabled?

        config = CommandTower.config.jwt.cookie.csrf
        options = csrf_cookie_options(expires_at: 1.year.ago)
        options[:value] = ""
        options[:max_age] = 0

        response.set_cookie(config.cookie_name, options)
      end

      # Ensure CSRF cookie exists (rotate-or-ensure model)
      # - If should_rotate is true → generate + set new CSRF cookie
      # - Else if existing cookie is blank → generate + set new CSRF cookie
      # - Else do nothing (cookie already exists)
      def ensure_cookie(request, response, should_rotate: false)
        return unless csrf_enabled?

        # Read cookie once into local variable
        existing_cookie = read_cookie(request)
        existing_cookie_blank = existing_cookie.nil? || existing_cookie.strip.empty?

        if should_rotate || existing_cookie_blank
          # Generate and set new CSRF cookie
          token = generate_token
          set_cookie(response, token)
        end
        # Else: cookie exists and we're not rotating, do nothing
      end

      # Read CSRF token from cookie
      def read_cookie(request)
        return nil unless csrf_enabled?

        config = CommandTower.config.jwt.cookie.csrf
        request.cookies[config.cookie_name]
      end

      # Read CSRF token from header
      def read_header(request)
        return nil unless csrf_enabled?

        config = CommandTower.config.jwt.cookie.csrf
        request.headers[config.header_name]
      end

      # Validate CSRF token (compare cookie to header)
      # Uses constant-time comparison for security hardening
      def validate(request)
        return { valid: true } unless csrf_enabled?

        # read_cookie and read_header also check csrf_enabled?, but that's fine for redundancy
        cookie_token = read_cookie(request)
        header_token = read_header(request)

        if cookie_token.nil? || cookie_token.strip.empty?
          return { valid: false, error: :csrf_missing, message: "csrf_missing" }
        end

        if header_token.nil? || header_token.strip.empty?
          return { valid: false, error: :csrf_mismatch, message: "csrf_missing" }
        end

        # Normalize tokens
        cookie_normalized = cookie_token.to_s.strip
        header_normalized = header_token.to_s.strip

        # Use constant-time comparison to prevent timing attacks
        if cookie_normalized.length != header_normalized.length
          return { valid: false, error: :csrf_mismatch, message: "csrf_mismatch" }
        end

        unless ActiveSupport::SecurityUtils.secure_compare(cookie_normalized, header_normalized)
          return { valid: false, error: :csrf_mismatch, message: "csrf_mismatch" }
        end

        { valid: true }
      end

      # Check if CSRF is enabled
      # CSRF can only be enabled when cookie auth is also enabled
      def csrf_enabled?
        CommandTower::Jwt::AuthorizationHelper.cookie_enabled? && CommandTower.config.jwt.cookie.csrf.enabled?
      end

      # Get cookie options (single source of truth)
      # Uses explicit nil checks (not ||) for true nil-coalescing of inheritable fields
      def csrf_cookie_options(expires_at:)
        config = CommandTower.config.jwt.cookie.csrf
        jwt_config = CommandTower.config.jwt.cookie

        # Boolean handling for secure (already fixed)
        secure_value = config.secure.nil? ? (jwt_config.secure.nil? ? Rails.env.production? : jwt_config.secure) : config.secure

        # Explicit nil checks for same_site, path, domain (not || to respect explicit false/nil)
        same_site_value = config.same_site.nil? ? jwt_config.same_site : config.same_site
        path_value = config.path.nil? ? jwt_config.path : config.path
        domain_value = config.domain.nil? ? jwt_config.domain : config.domain

        options = {
          expires: expires_at,
          httponly: false,  # CRITICAL: Must be readable by JavaScript (defined once)
          secure: secure_value,
          same_site: same_site_value,
          path: path_value
        }
        options[:domain] = domain_value if domain_value.present?
        options
      end
    end
  end
end
