# frozen_string_literal: true

module ApiEngineBase
  class AdminController < ::ApiEngineBase::ApplicationController
    include ApiEngineBase::SchemaHelper

    before_action :authenticate_user!
    before_action :authorize_user!
    before_action :user!, only: [:modify, :modify_role]

    # Pagination is needed here
    def show
      schemafied_users = User.all.map { ApiEngineBase::Schema::User.convert_user_object(user: _1) }
      schema = ApiEngineBase::Schema::Admin::Users.new(users: schemafied_users)
      schema_succesful!(status: 200, schema:)
    end

    def modify
      result = ApiEngineBase::UserAttributes::Modify.(user:, admin_user:, **modify_params)
      if result.success?
        schema = ApiEngineBase::Schema::User.convert_user_object(user: user.reload)
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
          server_error!(result:)
        end
      end
    end

    def modify_role
      result = ApiEngineBase::UserAttributes::Roles.(user:, admin_user:, roles: params[:roles])
      if result.success?
        schema = ApiEngineBase::Schema::User.convert_user_object(user: user.reload)
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
          server_error!(result:)
        end
      end
    end

    def impersonate
      # TODO: @matt-taylor
    end

    private

    def server_error!(result:)
      status = 500
      schema = ApiEngineBase::Schema::Error::Base.new(status:, message: result.msg)
      render(json: schema.to_h, status:)
    end

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

    def admin_user
      # current_user is defined via authenticate_user! before action
      current_user
    end

    def user!
      _user = User.where(id: params[:user_id]).first
      if _user
        @user = _user
        return true
      end

      status = 400
      schema = ApiEngineBase::Schema::Error::Base.new(status:, message: "Invalid user")
      render(json: schema.to_h, status:)
      # Must return false so callbacks know to halt propagation
      false
    end

    def user
      @user ||= nil
    end
  end
end
