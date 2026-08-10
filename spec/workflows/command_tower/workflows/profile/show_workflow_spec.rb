# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Profile::ShowWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user) }

    let(:user) { create(:user, roles: ["member"]) }

    it "returns the UserSerializer payload" do
      expect(result).to be_success
      expect(result.payload).to include(id: user.id, email: user.email)
      expect(result.payload).not_to have_key(:capabilities)
    end
  end
end
