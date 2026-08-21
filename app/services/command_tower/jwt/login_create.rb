# frozen_string_literal: true

module CommandTower::Jwt
  class LoginCreate
    IssuedToken = Data.define(:token)

    def self.call(user:, impersonation_session_id: nil)
      IssuedToken.new(token: Encode.(payload: payload_for(user, impersonation_session_id:)))
    end

    def self.payload_for(user, impersonation_session_id: nil)
      payload = {
        generated_at: Time.now.to_i,
        user_id: user.id,
        verifier_token: user.retreive_verifier_token!,
      }
      token = impersonation_session_id.to_s.strip
      payload[:impersonation_session_id] = token unless token.empty?
      payload
    end
    private_class_method :payload_for
  end
end
