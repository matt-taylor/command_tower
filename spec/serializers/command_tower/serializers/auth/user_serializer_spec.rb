# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::UserSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(user) }

    let(:user) { create(:user, email: "serialize@example.com", username: "serializeuser", roles: ["member"]) }

    it "returns camelCase auth user fields" do
      expect(payload).to eq(
        id: user.id,
        email: "serialize@example.com",
        username: "serializeuser",
        firstName: user.first_name,
        lastName: user.last_name,
        emailValidated: true,
        roles: ["member"]
      )
    end
  end
end
