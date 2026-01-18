# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText
  class ValidIdentifier < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :login_key_key, is_a: Symbol, required: true, sensitive: true
    validate :login_key, is_a: String, required: true, sensitive: true


    def call()
      if user.nil?
        log_warn("Login identifier not found: [#{login_key_key}] => [#{login_key}]")
        credential_mismatch!
        return
      end

      context.user = user
    end

    def credential_mismatch!
      msg = "Unauthorized Access. Incorrect Credentials"
      inline_argument_failure!(errors: { login_key_key => msg })
    end

    def user
      @user ||= ::User.where(login_key_key => login_key).first
    end
  end
end
