# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::EmailVerification
  class Verify < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true
    validate :code, is_a: String, required: true

    def call
      result = CommandTower::Secrets::Verify.(secret: code, reason: CommandTower::Secrets::EMAIL_VERIFICIATION)
      if result.failure?
        inline_argument_failure!(errors: { code:  "Incorrect verification code provided" })
      end

      if result.user != user
        log_warn("Yikes! The logged in user does not match the correct code. Kick them back out and do not verify")
        inline_argument_failure!(errors: { code:  "Incorrect verification code provided" })
      end

      user.update(email_validated: true)
    end
  end
end
