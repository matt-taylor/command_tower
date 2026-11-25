# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::IdentityPolicySerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(policy: policy) }

    let(:rule) { { id: "min_length", label: "At least 8 characters", check: "client" } }
    let(:policy) do
      {
        password: {
          min_length: 8,
          max_length: 64,
          max_bytes: 72,
          password_rules: "minlength: 8; maxlength: 64;",
          rules: [rule]
        },
        email: { min_length: 3, max_length: 254, rules: [rule] },
        username: {
          min_length: 4,
          max_length: 32,
          pattern: "^\\w{4,32}$",
          pattern_description: "letters and/or numbers",
          rules: [rule],
          self_service: true,
          self_change: false,
          prompt: "after_signup"
        },
        verification_code: { length: 6, character_set: "numeric" },
        phone_verification_code: { length: 6, character_set: "numeric" }
      }
    end

    it "builds the camelCase identity policy shape" do
      expect(payload).to eq(
        password: {
          minLength: 8,
          maxLength: 64,
          maxBytes: 72,
          passwordRules: "minlength: 8; maxlength: 64;",
          rules: [rule]
        },
        email: { minLength: 3, maxLength: 254, rules: [rule] },
        username: {
          minLength: 4,
          maxLength: 32,
          pattern: "^\\w{4,32}$",
          patternDescription: "letters and/or numbers",
          rules: [rule],
          selfService: true,
          selfChange: false,
          prompt: "after_signup"
        },
        verificationCode: { length: 6, characterSet: "numeric" },
        phoneVerificationCode: { length: 6, characterSet: "numeric" }
      )
    end
  end
end
