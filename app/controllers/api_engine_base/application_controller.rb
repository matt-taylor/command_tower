# frozen_string_literal: true

module ApiEngineBase
  class ApplicationController < ActionController::API
    AUTHORIZATION_HEADER = "AUTHORIZATION"

    def safe_boolean(value:)
      return nil unless [true, false, "true", "false", "0", "1", 0, 1].include?(value)

      ActiveModel::Type::Boolean.new.cast(value)
    end

    ###
    # AUTHORIZATION_HEADER="Bearer: {token value}"
    def authenticate_user!(bypass_email_validation: false)
      raw_token = request.headers[AUTHORIZATION_HEADER]
      if raw_token.nil?
        status = 401
        schema = ApiEngineBase::Schema::Error::Base.new(status:, message: "Bearer token missing")
        render(json: schema.to_h, status:)
        return false
      end

      token = raw_token.split("Bearer:")[1].strip
      result = ApiEngineBase::Jwt::AuthenticateUser.(token:, bypass_email_validation:)
      if result.success?
        @current_user = result.user
        true
      else
        status = 401
        schema = ApiEngineBase::Schema::Error::Base.new(status:, message: result.msg)
        render(json: schema.to_h, status:)
        # Must return false so callbacks know to halt propagation
        false
      end
    end

    def authenticate_user_without_email_verification!
      authenticate_user!(bypass_email_validation: true)
    end

    def authorize_user!
      if current_user.nil?
        Rails.logger.error { "Current User is not defined. This means that authenticate_user! was not called" }
        status = 401
        schema = ApiEngineBase::Schema::Error::Base.new(status:, message: "Bearer token missing")
        render(json: schema.to_h, status:)
        return false
      end
      result = ApiEngineBase::Authorize::Validate.(user: current_user, controller: self.class, method: params[:action])

      if result.success?
        @current_user = result.user
        true
      else
        # Current user is not authorized for the current Controller#action
        status = 403
        schema = ApiEngineBase::Schema::Error::Base.new(status:, message: result.msg)
        render(json: schema.to_h, status:)
        # Must return false so callbacks know to halt propagation
        false
      end
    end

    def current_user
      @current_user ||= nil
    end

    def add_to_body
      # {
      #   token_valid_till:,
      #   needs_email_verification:,
      # }
    end
  end
end
