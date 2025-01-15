module ApiEngineBase
  module Auth
    class PlainTextController < ::ApiEngineBase::ApplicationController
      include ApiEngineBase::SchemaHelper

      before_action :authenticate_user_without_email_verification!, only: [:email_verify_post, :email_verify_resend_post]

      # POST /auth/login
      # Login to the application and create/set the JWT token
      def login_post
        result = ApiEngineBase::LoginStrategy::PlainText::Login.(**login_params)
        if result.success?
          schema = ApiEngineBase::Schema::PlainText::LoginResponse.new(
            token: result.token,
            header_name: AUTHENTICATION_HEADER,
            message: "Successfully logged user in"
          )
          status = 201
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 401,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: ApiEngineBase::Schema::PlainText::LoginRequest
            )
          else
            json_result = { msg: result.msg }
            status = 400
            render(json: schema.to_h, status:)
          end
        end
      end

      # POST /auth/create
      # New PlainText user creation
      def create_post
        result = ApiEngineBase::LoginStrategy::PlainText::Create.(**create_params)
        if result.success?
          schema = ApiEngineBase::Schema::PlainText::CreateUserResponse.new(
            full_name: result.user.full_name,
            first_name: result.first_name,
            last_name: result.last_name,
            username: result.username,
            email: result.email,
            msg: "Successfully created new User",
          )
          status = 201
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 400,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: ApiEngineBase::Schema::PlainText::CreateUserRequest
            )
          end
        end
      end

      # POST /auth/email/verify
      # Verifies a logged in users email verification code when enabled
      def email_verify_post
        if current_user.email_validated
          schema = ApiEngineBase::Schema::PlainText::EmailVerifyResponse.new(message: "Email is already verified.")
          status = 200
          schema_succesful!(status:, schema:)
        else
          result = ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Verify.(user: current_user, code: params[:code])
          if result.success?
            schema = ApiEngineBase::Schema::PlainText::EmailVerifyResponse.new(message: "Successfully verified email")
            status = 201
            schema_succesful!(status:, schema:)
          else
            if result.invalid_arguments
              invalid_arguments!(
                status: result.status || 403,
                message: result.msg,
                argument_object: result.invalid_argument_hash,
                schema: ApiEngineBase::Schema::PlainText::EmailVerifyRequest
              )
            end
          end
        end
      end

      # POST /auth/email/send
      # Sends a logged in users email verification code
      def email_verify_resend_post
        if current_user.email_validated
          schema = ApiEngineBase::Schema::PlainText::EmailVerifyResponse.new(message: "Email is already verified. No code required")
          status = 200
          schema_succesful!(status:, schema:)
        else
          result = ApiEngineBase::LoginStrategy::PlainText::EmailVerification::Send.(user: current_user)
          if result.success?
            schema = ApiEngineBase::Schema::PlainText::EmailVerifyResponse.new(message: "Successfully sent Email verification code")
            status = 201
            schema_succesful!(status:, schema:)
          else
            schema = ApiEngineBase::Schema::Error::Base.new(status:, message: result.msg)
            status = result.status || 401
            render(json: schema.to_h, status:)
          end
        end
      end

      private

      def login_params
        {
          username: params[:username],
          email: params[:email],
          password: params[:password],
        }
      end

      def create_params
        {
          first_name: params[:first_name],
          last_name: params[:last_name],
          username: params[:username],
          email: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
        }
      end
    end
  end
end
