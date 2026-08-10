# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::RegisterResponseSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(user: user) }

    let(:user) { create(:user) }

    it "builds the register response shape" do
      expect(payload).to eq(
        user: CommandTower::Serializers::Auth::UserSerializer.serialize(user),
        message: "Account created successfully"
      )
    end

    it "omits any token" do
      expect(payload).not_to have_key(:token)
    end
  end
end
