# frozen_string_literal: true

module CommandTower
  module SpecHelper
    def set_jwt_token!(user:, with_reset: false, token: nil)
      if token.nil?
        result = CommandTower::Jwt::LoginCreate.(user:)
        token = result.token
      end

      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = "Bearer: #{token}"
      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_WITH_RESET] = "true" if with_reset
    end

    def unset_jwt_token!
      @request.headers[CommandTower::ApplicationController::AUTHENTICATION_HEADER] = nil
    end
  end
end
