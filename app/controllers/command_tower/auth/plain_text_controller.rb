module CommandTower
  module Auth
    class PlainTextController < ::CommandTower::ApplicationController
      include CommandTower::SchemaHelper

      before_action :authenticate_user_without_email_verification!, only: [:email_verify_post, :email_verify_resend_post]
      before_action :authenticate_user!, only: [:password_change_post]

      # POST /auth/login
      # Login to the application and create/set the JWT token
      def login_post
        result = CommandTower::LoginStrategy::PlainText::Login.(**login_params)
        if result.success?
          # Set token in response (headers and cookie if enabled)
          expires_at = CommandTower.config.jwt.ttl.from_now.to_time.to_s
          CommandTower::Jwt::AuthorizationHelper.set_token(
            response,
            result.token,
            expires_at: expires_at
          )

          # Handle CSRF cookie issuance/rotation for login flow (rotate-or-ensure model)
          # CSRF cookie issuance rules:
          # - CSRF cookie must ALWAYS exist when CSRF is enabled
          # - rotate_on_login = false means:
          #   * do NOT force rotation (if cookie exists, keep it)
          #   * but DO create the cookie if missing
          # - rotate_on_login = true means: always force rotation (generate new token)
          if CommandTower::Jwt::CsrfHelper.csrf_enabled?
            config = CommandTower.config.jwt.cookie.csrf
            # Always ensure cookie exists; rotate_on_login only controls whether to force rotation
            CommandTower::Jwt::CsrfHelper.ensure_cookie(request, response, should_rotate: config.rotate_on_login)
          end

          schema = CommandTower::Schema::Auth::PlainText::Login::Response.new(
            token: result.token,
            header_name: AUTHENTICATION_HEADER,
            user: CommandTower::Schema::Shared::User.convert_user_object(user: result.user),
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
              schema: CommandTower::Schema::Auth::PlainText::Login::Request
            )
          else
            json_result = { msg: result.msg }
            status = 400
            render(json: schema.to_h, status:)
          end
        end
      end

      # GET /auth/login/identifier/valid
      # Checks if a login identifier is valid
      def login_identifier_valid_get
        identifier = params[:identifier]
        login_key_key = identifier&.include?("@") ? :email : :username
        result = CommandTower::LoginStrategy::PlainText::ValidIdentifier.(
          login_key_key: login_key_key,
          login_key: identifier
        )
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::LoginIdentifierValid::Response.new(
            valid: true,
            message: "Login identifier is valid",
            user: CommandTower::Schema::Shared::User.convert_user_object(user: result.user)
          )
          status = 200
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 400,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: CommandTower::Schema::Auth::PlainText::LoginIdentifierValid::Request
            )
          else
            status = 400
            schema = CommandTower::Schema::Error::Base.new(status:, message: result.msg)
            render(json: schema.to_h, status:)
          end
        end
      end

      # POST /auth/create
      # New PlainText user creation
      def create_post
        result = CommandTower::LoginStrategy::PlainText::Create.(**create_params)
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::CreateUser::Response.new(
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
              schema: CommandTower::Schema::Auth::PlainText::CreateUser::Request
            )
          end
        end
      end

      # POST /auth/email/verify
      # Verifies a logged in users email verification code when enabled
      def email_verify_post
        if current_user.email_validated
          schema = CommandTower::Schema::Auth::PlainText::EmailVerify::Response.new(message: "Email is already verified.")
          status = 200
          schema_succesful!(status:, schema:)
        else
          result = CommandTower::LoginStrategy::PlainText::EmailVerification::Verify.(user: current_user, code: params[:code])
          if result.success?
            schema = CommandTower::Schema::Auth::PlainText::EmailVerify::Response.new(message: "Successfully verified email")
            status = 201
            schema_succesful!(status:, schema:)
          else
            if result.invalid_arguments
              invalid_arguments!(
                status: result.status || 403,
                message: result.msg,
                argument_object: result.invalid_argument_hash,
                schema: CommandTower::Schema::Auth::PlainText::EmailVerify::Request
              )
            end
          end
        end
      end

      # POST /auth/email/send
      # Sends a logged in users email verification code
      def email_verify_resend_post
        if current_user.email_validated
          schema = CommandTower::Schema::Auth::PlainText::EmailVerify::SendResponse.new(message: "Email is already verified. No code required")
          status = 200
          schema_succesful!(status:, schema:)
        else
          result = CommandTower::LoginStrategy::PlainText::EmailVerification::Send.(user: current_user)
          if result.success?
            schema = CommandTower::Schema::Auth::PlainText::EmailVerify::SendResponse.new(message: "Successfully sent Email verification code")
            status = 201
            schema_succesful!(status:, schema:)
          else
            schema = CommandTower::Schema::Error::Base.new(status:, message: result.msg)
            status = result.status || 401
            render(json: schema.to_h, status:)
          end
        end
      end

      # POST /auth/password/change
      # Authenticated password change — rotates verifier; does not re-issue JWT
      def password_change_post
        result = CommandTower::LoginStrategy::PlainText::ChangePassword.(
          user: current_user,
          **password_change_params
        )
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::ChangePassword::Response.new(
            message: result.message
          )
          status = 200
          schema_succesful!(status:, schema:)
        elsif result.invalid_arguments
          invalid_arguments!(
            status: 400,
            message: result.msg,
            argument_object: result.invalid_argument_hash,
            schema: CommandTower::Schema::Auth::PlainText::ChangePassword::Request
          )
        else
          status = result.status || 500
          schema = CommandTower::Schema::Error::Base.new(status:, message: result.msg)
          render(json: schema.to_h, status:)
        end
      end

      # POST /auth/password/forgot/send
      # Request password reset email
      def password_forgot_send_post
        result = CommandTower::LoginStrategy::PlainText::PasswordReset::Send.(**password_forgot_send_params)
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::PasswordForgot::Send::Response.new(
            message: result.message
          )
          status = 200
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 400,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: CommandTower::Schema::Auth::PlainText::PasswordForgot::Send::Request
            )
          else
            schema = CommandTower::Schema::Error::Base.new(status: result.status || 400, message: result.msg)
            status = result.status || 400
            render(json: schema.to_h, status:)
          end
        end
      end

      # POST /auth/password/forgot/validate
      # Validate password reset token
      def password_forgot_validate_post
        result = CommandTower::LoginStrategy::PlainText::PasswordReset::Validate.(**password_forgot_validate_params)
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::PasswordForgot::Validate::Response.new(
            valid: result.valid,
            expires_at: result.expires_at
          )
          status = 200
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 400,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: CommandTower::Schema::Auth::PlainText::PasswordForgot::Validate::Request
            )
          else
            schema = CommandTower::Schema::Error::Base.new(status: result.status || 401, message: result.msg)
            status = result.status || 401
            render(json: schema.to_h, status:)
          end
        end
      end

      # POST /auth/password/forgot/reset
      # Reset password with token
      def password_forgot_reset_post
        result = CommandTower::LoginStrategy::PlainText::PasswordReset::Reset.(**password_forgot_reset_params)
        if result.success?
          schema = CommandTower::Schema::Auth::PlainText::PasswordForgot::Reset::Response.new(
            message: result.message
          )
          status = 200
          schema_succesful!(status:, schema:)
        else
          if result.invalid_arguments
            invalid_arguments!(
              status: 400,
              message: result.msg,
              argument_object: result.invalid_argument_hash,
              schema: CommandTower::Schema::Auth::PlainText::PasswordForgot::Reset::Request
            )
          else
            schema = CommandTower::Schema::Error::Base.new(status: result.status || 401, message: result.msg)
            status = result.status || 401
            render(json: schema.to_h, status:)
          end
        end
      end

      private

      def login_params
        {
          identifier: params[:identifier],
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

      def password_change_params
        {
          current_password: params[:current_password],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
        }
      end

      def password_forgot_send_params
        {
          email: params[:email],
        }
      end

      def password_forgot_validate_params
        {
          token: params[:token],
          email: params[:email],
        }
      end

      def password_forgot_reset_params
        {
          token: params[:token],
          email: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
        }
      end
    end
  end
end
