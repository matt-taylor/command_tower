# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Users::ShowWorkflow do
  describe ".call" do
    context "when the user exists" do
      subject(:result) { described_class.call(id: user.id, user:) }

      let(:user) { create(:user) }

      it { expect(result).to be_success }

      it "serializes the user" do
        expect(result.payload.fetch(:id)).to eq(user.id)
        expect(result.payload).not_to have_key(:passwordDigest)
      end
    end

    context "when the user is missing" do
      subject(:result) { described_class.call(id: 0, user: create(:user)) }

      it { expect(result).to be_failure }

      it "maps to not_found" do
        expect(result.http_status).to eq(:not_found)
      end
    end
  end
end
