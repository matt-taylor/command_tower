# frozen_string_literal: true

module CommandTower::Jwt
  class LoginCreate
    IssuedToken = Data.define(:token)

    def self.call(user:)
      IssuedToken.new(token: Encode.(payload: payload_for(user)))
    end

    def self.payload_for(user)
      {
        generated_at: Time.now.to_i,
        user_id: user.id,
        verifier_token: user.retreive_verifier_token!,
      }
    end
    private_class_method :payload_for
  end
end
