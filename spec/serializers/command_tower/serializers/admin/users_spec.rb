# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Admin::Users::UserSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(user) }

    let(:user) { create(:user, first_name: "Ada", last_name: "Lovelace", username: "ada") }

    it "projects the safe allowlist" do
      expect(payload.keys).to contain_exactly(
        :id, :firstName, :lastName, :fullName, :username, :email,
        :emailValidated, :phoneNumber, :phoneNumberValidated, :roles, :createdAt
      )
      expect(payload.fetch(:fullName)).to eq("Ada Lovelace")
      expect(payload).not_to have_key(:passwordDigest)
      expect(payload).not_to have_key(:verifierToken)
    end
  end
end

RSpec.describe CommandTower::Serializers::Admin::Users::AssignableRolesSerializer do
  describe ".serialize" do
    subject(:payload) do
      described_class.serialize(
        [
          { name: "member", description: "Standard authenticated application user" }
        ]
      )
    end

    it "projects name and description" do
      expect(payload).to eq(
        roles: [
          { name: "member", description: "Standard authenticated application user" }
        ]
      )
    end
  end
end
