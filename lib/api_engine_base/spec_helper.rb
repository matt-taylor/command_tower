# frozen_string_literal: true

module ApiEngineBase
  module SpecHelper
    def set_jwt_token!(user:, token: nil)
      if token.nil?
        result = ApiEngineBase::Jwt::LoginCreate.(user:)
        token = result.token
      end

      @request.headers[ApiEngineBase::ApplicationController::AUTHORIZATION_HEADER] = "Bearer: #{token}"
    end

    def unset_jwt_token!
      @request.headers[ApiEngineBase::ApplicationController::AUTHORIZATION_HEADER] = nil
    end
  end
end
