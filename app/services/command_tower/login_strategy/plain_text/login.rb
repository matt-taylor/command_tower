# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText
  class Login < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :identifier, is_a: String, required: true, sensitive: true
    validate :password, is_a: String, required: true, sensitive: true

    def call
      if user.nil?
        msg = "Unauthorized Access. Incorrect Credentials"
        invalid_argument_hash = { identifier: { msg: }, password: { msg: } }
        invalid_argument_keys = [:identifier, :password]
        context.fail!(msg:, invalid_argument_hash:, invalid_argument_keys:, invalid_arguments: true)
        return
      end

      if user.authenticate(password)
        user.successful_login += 1
        user.password_consecutive_fail = 0
        user.save
      else
        user.password_consecutive_fail += 1
        user.save
        log_warn("Valid identifier. Incorrect password. Consecutive Password failures: #{user.password_consecutive_fail}")
        credential_mismatch!
      end

      context.user = user

      result = CommandTower::Jwt::LoginCreate.(user:)
      if result.failure?
        context.fail!(msg: "Failed to generate Authorization. Please Try again")
        return
      end

      context.token = result.token
    end

    def credential_mismatch!
      msg = "Unauthorized Access. Incorrect Credentials"
      inline_argument_failure!(errors: { identifier: msg, password: msg })
    end

    def user
      @user ||= User.where(username: identifier).or(User.where(email: identifier)).first
    end
  end
end
