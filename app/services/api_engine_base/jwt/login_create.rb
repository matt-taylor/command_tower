# frozen_string_literal: true

module ApiEngineBase::Jwt
  class LoginCreate < ApiEngineBase::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true

    def call
      context.token = Encode.(payload:).token
    end

    def payload
      {
        generated_at: Time.now.to_i,
        user_id: user.id,
        verifier_token: user.retreive_verifier_token!,
      }
    end
  end
end
