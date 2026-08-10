# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::LoginResponseSerializer do
  describe ".serialize" do
    subject(:payload) do
      described_class.serialize(user: user, token: "tok", token_expires_at: "exp")
    end

    let(:user) do
      create(
        :user,
        email: "ser@example.com",
        username: "serspec",
        first_name: "A",
        last_name: "B",
        roles: ["member"]
      )
    end

    it "returns login contract keys" do
      expect(payload).to include(
        token: "tok",
        tokenExpiresAt: "exp"
      )
      expect(payload[:user]).to include(
        id: user.id,
        email: "ser@example.com",
        username: "serspec",
        firstName: "A",
        lastName: "B",
        emailValidated: true,
        roles: ["member"]
      )
    end
  end
end
