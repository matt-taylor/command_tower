# frozen_string_literal: true

module CommandTower
  class ApplicationController < ActionController::API
    AUTHENTICATION_HEADER = CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_HEADER
    AUTHENTICATION_EXPIRE_HEADER = CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER
    AUTHENTICATION_WITH_RESET = CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_WITH_RESET

    def safe_boolean(value:)
      return nil unless [true, false, "true", "false", "0", "1", 0, 1].include?(value)

      ActiveModel::Type::Boolean.new.cast(value)
    end

    ###
    # Authenticate user via the passed in header or cookie
    # AUTHENTICATION_HEADER="Bearer {token value}" or cookie (if enabled)
    def authenticate_user!(bypass_email_validation: false)
      # Extract and validate token (from header or cookie fallback)
      token_data = CommandTower::Jwt::AuthorizationHelper.extract_token(request)
      if token_data[:error]
        status = 401
        schema = CommandTower::Schema::Error::Base.new(status:, message: token_data[:message])
        render(json: schema.to_h, status:)
        return false
      end

      token = token_data[:token]
      token_source = token_data[:source]

      # CSRF validation for cookie-authenticated unsafe requests
      # Enforcement is centralized here because token_source is only reliably known in this shared filter
      if csrf_required?(request, token_source)
        csrf_validation = CommandTower::Jwt::CsrfHelper.validate(request)
        unless csrf_validation[:valid]
          status = 403
          schema = CommandTower::Schema::Error::Base.new(
            status: status.to_s,
            message: csrf_validation[:message]  # Stable error code: "csrf_missing" or "csrf_mismatch"
          )
          render(json: schema.to_h, status: status)
          return false
        end
      end

      with_reset = CommandTower::Jwt::AuthorizationHelper.get_with_reset_flag(request)
      result = CommandTower::Jwt::AuthenticateUser.(token:, bypass_email_validation:, with_reset:)
      if result.success?
        @current_user = result.user
        if with_reset
          # Use helper to set both headers and cookie (if enabled)
          CommandTower::Jwt::AuthorizationHelper.set_token(
            response,
            result.generated_token,
            expires_at: result.expires_at
          )

          # Handle CSRF cookie issuance/rotation for token reset path
          # CSRF cookie issuance rules:
          # - rotate_on_reset = true → force rotate (generate new token)
          # - rotate_on_reset = false → ensure exists only (create if missing, keep if exists)
          if CommandTower::Jwt::CsrfHelper.csrf_enabled?
            if CommandTower.config.jwt.cookie.csrf.rotate_on_reset
              CommandTower::Jwt::CsrfHelper.ensure_cookie(request, response, should_rotate: true)
            else
              # Ensure cookie exists (rotate-or-ensure model)
              CommandTower::Jwt::CsrfHelper.ensure_cookie(request, response, should_rotate: false)
            end
          end
        else
          # Only set expire header when not resetting
          response.set_header(AUTHENTICATION_EXPIRE_HEADER, result.expires_at)
        end
        true
      else
        # Check if this is an email validation failure (status 412)
        if result.status == 412
          status = 412
          schema = CommandTower::Schema::Error::EmailValidationRequired.new(
            status:,
            message: result.msg,
            meta: { email_validated: false }
          )
          # Do NOT clear cookie for 412 status - user needs to keep cookie to verify email
        else
          # If authentication failed and token came from cookie, clear the invalid cookie
          # Exception: Do not clear cookie for 412 status (email validation required)
          if token_source == :cookie
            CommandTower::Jwt::AuthorizationHelper.clear_cookie(response)
          end
          status = result.status || 401
          schema = CommandTower::Schema::Error::Base.new(status:, message: result.msg)
        end
        render(json: schema.to_h, status:)
        # Must return false so callbacks know to halt propagation
        false
      end
    end

    ###
    # Authenticate user via the passed in header without validating email
    def authenticate_user_without_email_verification!
      authenticate_user!(bypass_email_validation: true)
    end

    ###
    # After Authenticating user, see if the user needs authorization on the route
    def authorize_user!
      if current_user.nil?
        Rails.logger.error { "Current User is not defined. This means that authenticate_user! was not called" }
        status = 401
        schema = CommandTower::Schema::Error::Base.new(status:, message: "Bearer token missing")
        render(json: schema.to_h, status:)
        return false
      end
      result = CommandTower::Authorize::Validate.(user: current_user, controller: self.class, method: params[:action])

      if result.success?
        @current_user = result.user
        true
      else
        # Current user is not authorized for the current Controller#action
        status = 403
        schema = CommandTower::Schema::Error::Base.new(status:, message: result.msg)
        render(json: schema.to_h, status:)
        # Must return false so callbacks know to halt propagation
        false
      end
    end

    def current_user
      @current_user ||= nil
    end

    private

    def csrf_required?(request, token_source)
      return false unless CommandTower::Jwt::CsrfHelper.csrf_enabled?
      # CRITICAL: Check token_source, not cookie presence
      return false unless token_source == :cookie
      return false if request.get? || request.head? || request.options?

      # Unsafe methods: POST, PUT, PATCH, DELETE
      %w[POST PUT PATCH DELETE].include?(request.method)
    end
  end
end
