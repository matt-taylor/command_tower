# frozen_string_literal: true

RSpec.describe CommandTower::Authorization::AssignableRoles, :with_rbac_setup do
  describe ".catalog" do
    subject(:catalog) { described_class.catalog }

    it "includes host-sourced roles" do
      expect(catalog.map { |row| row.fetch(:name) }).to include("member", "support_admin", "rbac_admin")
    end

    it "excludes owner" do
      expect(catalog.map { |row| row.fetch(:name) }).not_to include("owner")
    end
  end

  describe ".assignable_name?" do
    it { expect(described_class.assignable_name?("member")).to eq(true) }

    it { expect(described_class.assignable_name?("owner")).to eq(false) }
  end
end
