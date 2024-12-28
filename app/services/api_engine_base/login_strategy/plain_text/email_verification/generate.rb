# frozen_string_literal: true

module ApiEngineBase::LoginStrategy::PlainText::EmailVerification
  class Generate < ApiEngineBase::ServiceBase
    validate :user, is_a: User, required: true

    def call
      result = ApiEngineBase::Secrets::Generate.(
        user:,
        secret_length: email_verify.verify_code_length,
        reason: ApiEngineBase::Secrets::EMAIL_VERIFICIATION,
        use_count_max: 1,
        death_time: email_verify.verify_code_link_valid_for,
        type: ApiEngineBase::Secrets::NUMERIC,
        cleanse: true,
      )

      if result.failure?
        context.fail!(msg: "Secret Generation is not available at this time")
      end

      context.secret = result.secret
    end

    def email_verify
      ApiEngineBase.config.login.plain_text.email_verify
    end
  end
end
