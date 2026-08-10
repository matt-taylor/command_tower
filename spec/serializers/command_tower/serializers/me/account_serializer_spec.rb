# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Me::AccountSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(user, capabilities: capabilities) }

    let(:user) { create(:user, first_name: "Ada", last_name: "Lovelace", roles: ["member"]) }
    let(:capabilities) { { editName: { enabled: true } } }

    it "includes identity and account fields" do
      expect(payload).to include(
        id: user.id,
        firstName: "Ada",
        lastName: "Lovelace",
        fullName: "Ada Lovelace",
        username: user.username,
        email: user.email,
        emailValidated: true,
        roles: ["member"],
        capabilities: capabilities
      )
      expect(payload[:createdAt]).to be_present
    end
  end
end
