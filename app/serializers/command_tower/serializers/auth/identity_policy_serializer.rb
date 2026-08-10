# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class IdentityPolicySerializer
        def self.serialize(policy:)
          {
            password: {
              minLength: policy[:password][:min_length],
              maxLength: policy[:password][:max_length]
            },
            email: {
              minLength: policy[:email][:min_length],
              maxLength: policy[:email][:max_length]
            },
            username: {
              minLength: policy[:username][:min_length],
              maxLength: policy[:username][:max_length],
              pattern: policy[:username][:pattern],
              patternDescription: policy[:username][:pattern_description]
            },
            verificationCode: {
              length: policy[:verification_code][:length],
              characterSet: policy[:verification_code][:character_set]
            },
            phoneVerificationCode: {
              length: policy[:phone_verification_code][:length],
              characterSet: policy[:phone_verification_code][:character_set]
            }
          }
        end
      end
    end
  end
end
