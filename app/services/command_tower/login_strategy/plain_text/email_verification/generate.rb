# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::EmailVerification
  class Generate < CommandTower::ServiceBase
    validate :user, is_a: User, required: true

    def call
      result = CommandTower::Secrets::Generate.(
        user:,
        secret_length: email_verify.verify_code_length,
        reason: CommandTower::Secrets::EMAIL_VERIFICIATION,
        use_count_max: 1,
        death_time: email_verify.verify_code_link_valid_for,
        type: CommandTower::Secrets::NUMERIC,
        cleanse: true,
      )

      if result.failure?
        context.fail!(msg: "Secret Generation is not available at this time")
      end

      context.secret = result.secret
    end

    def email_verify
      CommandTower.config.login.plain_text.email_verify
    end
  end
end
