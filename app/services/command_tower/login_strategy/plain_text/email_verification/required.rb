# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::EmailVerification
  class Required < CommandTower::ServiceBase
    validate :user, is_a: User, required: true

    def call
      context.reqired_after_time = reqired_after_time
      context.required = Time.now > reqired_after_time
    end

    def reqired_after_time
      user.created_at + email_verify.verify_email_required_within
    end

    def email_verify
      CommandTower.config.login.plain_text.email_verify
    end
  end
end
