# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::Users::ListAssignableRolesWorkflow, :with_rbac_setup do
  describe ".call" do
    subject(:result) { described_class.call }

    it { expect(result).to be_success }

    it "serializes the assignable catalog payload" do
      expect(result.payload.fetch(:roles).map { |row| row.fetch(:name) }).to include("member")
      expect(result.payload.fetch(:roles).map { |row| row.fetch(:name) }).not_to include("owner")
      expect(result.http_status).to eq(:ok)
    end
  end
end
