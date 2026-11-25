# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class IdentityPolicySerializer
        def self.serialize(policy:)
          {
            password: {
              minLength: policy[:password][:min_length],
              maxLength: policy[:password][:max_length],
              maxBytes: policy[:password][:max_bytes],
              passwordRules: policy[:password][:password_rules],
              rules: serialize_rules(policy[:password][:rules])
            },
            email: {
              minLength: policy[:email][:min_length],
              maxLength: policy[:email][:max_length],
              rules: serialize_rules(policy[:email][:rules])
            },
            username: {
              minLength: policy[:username][:min_length],
              maxLength: policy[:username][:max_length],
              pattern: policy[:username][:pattern],
              patternDescription: policy[:username][:pattern_description],
              rules: serialize_rules(policy[:username][:rules]),
              selfService: policy[:username][:self_service],
              selfChange: policy[:username][:self_change],
              prompt: policy[:username][:prompt]
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

        def self.serialize_rules(rules)
          rules.map { |rule| { id: rule[:id], label: rule[:label], check: rule[:check] } }
        end
        private_class_method :serialize_rules
      end
    end
  end
end
