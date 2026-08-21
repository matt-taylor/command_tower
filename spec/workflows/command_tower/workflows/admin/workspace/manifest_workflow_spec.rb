# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Workspace::ManifestWorkflow, :with_rbac_setup do
  describe ".call" do
    subject(:result) { described_class.call(user: admin) }

    let(:admin) { create(:user, :role_admin) }

    it { expect(result).to be_success }

    it "returns a serialized manifest payload" do
      expect(result.payload[:tools].map { |tool| tool[:id] }).to eq(%w[messaging users audit])
      expect(result.payload[:tools].first).to include(:sortOrder)
    end
  end
end
