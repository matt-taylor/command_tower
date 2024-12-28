# frozen_string_literal: true

module ApiEngineBase::LoginStrategy::PlainText::EmailVerification
  class Send < ApiEngineBase::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true

    def call
      result = Generate.(user:)
      if result.failure?
        context.fail!(msg: result.msg)
      end

      begin
        ApiEngineBase::EmailVerificationMailer.verify_email(user.email, user, result.secret).deliver
      rescue StandardError => e
        log_error("Failed to send message to [#{user.id}]: #{e.message}")
        context.fail!(msg: "Unable to send email. Please try again later", status: 500)
      end
    end
  end
end
