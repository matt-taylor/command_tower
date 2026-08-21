# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Users::ListAssignableRoles, :with_rbac_setup do
  describe ".call" do
    subject(:result) { described_class.call }

    it { expect(result).to be_success }

    it "returns host-sourced roles without owner" do
      expect(result.data[:roles].map { |row| row.fetch(:name) }).to include("member", "support_admin")
      expect(result.data[:roles].map { |row| row.fetch(:name) }).not_to include("owner")
    end
  end
end
