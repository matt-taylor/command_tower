# frozen_string_literal: true

module ApiEngineBase::LoginStrategy::PlainText
  class Login < ApiEngineBase::ServiceBase
    on_argument_validation :fail_early

    one_of(:login_key, required: true) do
      validate :username, is_a: String, sensitive: true
      validate :email, is_a: String, sensitive: true
    end
    validate :password, is_a: String, required: true, sensitive: true

    def call
      if user.nil?
        log_warn("Login attempted with [#{login_key_key}] => [#{login_key}]. Resource not found")
        credential_mismatch!
      end

      if user.authenticate(password)
        user.successful_login += 1
        user.password_consecutive_fail = 0
        user.save
      else
        user.password_consecutive_fail += 1
        user.save
        log_warn("Valid #{login_key_key}. Incorrect password. Consecutive Password failures: #{user.password_consecutive_fail}")
        credential_mismatch!
      end

      context.user = user

      result = ApiEngineBase::Jwt::LoginCreate.(user:)
      if result.failure?
        context.fail!(msg: "Failed to generate Authorization. Please Try again")
        return
      end

      context.token = result.token
    end

    def credential_mismatch!
      msg = "Unauthorized Access. Incorrect Credentials"
      inline_argument_failure!(errors: { login_key_key => msg, password: msg })
    end

    def user
      @user ||= User.where(login_key_key => login_key).first
    end
  end
end
