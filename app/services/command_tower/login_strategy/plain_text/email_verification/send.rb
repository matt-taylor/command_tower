# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::EmailVerification
  class Send < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true

    def call
      result = Generate.(user:)
      if result.failure?
        context.fail!(msg: result.msg)
      end

      begin
        template_name = CommandTower.config.login.plain_text.email_verify.custom_template_name
        CommandTower::EmailVerificationMailer.verify_email(user.email, user, result.secret, template_name: template_name).deliver
      rescue StandardError => e
        log_error("Failed to send message to [#{user.id}]: #{e.message}")
        context.fail!(msg: "Unable to send email. Please try again later", status: 500)
      end
    end
  end
end
