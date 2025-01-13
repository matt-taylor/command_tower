# frozen_string_literal: true

module ApiEngineBase
  class UserController < ::ApiEngineBase::ApplicationController
    include ApiEngineBase::SchemaHelper

    before_action :authenticate_user!

    def show
      schema = ApiEngineBase::Schema::User.convert_user_object(user: current_user)
      schema_succesful!(status: 200, schema:)
    end

    def modify
      result = ApiEngineBase::UserAttributes::Modify.(user: current_user, **modify_params)
      if result.success?
        schema = ApiEngineBase::Schema::User.convert_user_object(user: current_user.reload)
        status = 201
        schema_succesful!(status:, schema:)
      else
        if result.invalid_arguments
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: ApiEngineBase::Schema::PlainText::LoginRequest
          )
        else
          status = 500
          schema = ApiEngineBase::Schema::Error::Base.new(status:, message: result.msg)
          render(json: schema.to_h, status:)
        end
      end
    end

    private

    def modify_params
      {
        email: params[:email],
        email_validated: safe_boolean(value: params[:email_validated]),
        first_name: params[:first_name],
        last_name: params[:last_name],
        username: params[:username],
        verifier_token: safe_boolean(value: params[:verifier_token]),
      }.compact
    end
  end
end
