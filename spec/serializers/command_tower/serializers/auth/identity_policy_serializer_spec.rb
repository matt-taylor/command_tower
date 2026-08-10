# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::IdentityPolicySerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(policy: policy) }

    let(:policy) do
      {
        password: { min_length: 9, max_length: 63 },
        email: { min_length: 9, max_length: 63 },
        username: {
          min_length: 4,
          max_length: 32,
          pattern: "^\\w{4,32}$",
          pattern_description: "letters and/or numbers"
        },
        verification_code: { length: 6, character_set: "numeric" },
        phone_verification_code: { length: 6, character_set: "numeric" }
      }
    end

    it "builds the camelCase identity policy shape" do
      expect(payload).to eq(
        password: { minLength: 9, maxLength: 63 },
        email: { minLength: 9, maxLength: 63 },
        username: {
          minLength: 4,
          maxLength: 32,
          pattern: "^\\w{4,32}$",
          patternDescription: "letters and/or numbers"
        },
        verificationCode: { length: 6, characterSet: "numeric" },
        phoneVerificationCode: { length: 6, characterSet: "numeric" }
      )
    end
  end
end
