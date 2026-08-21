# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Workspace::Manifest, :with_rbac_setup do
  describe ".call" do
    context "when the user is a host admin" do
      subject(:result) { described_class.call(user: admin) }

      let(:admin) { create(:user, :role_admin) }

      it { expect(result).to be_success }

      it "returns CommandTower tools the admin is granted, in deterministic order" do
        expect(result.data[:tools].map { |tool| tool[:id] }).to eq(%w[messaging users audit])
      end

      it "projects presentation description without affecting authorization" do
        expect(result.data[:tools].find { |tool| tool[:id] == "audit" }[:description]).to eq(
          "Browse account and administrative audit history."
        )
        expect(result.data[:tools].find { |tool| tool[:id] == "audit" }.keys).to contain_exactly(
          :id, :label, :description, :route, :group, :sort_order, :icon
        )
      end

      it "does not include the dummy host tool" do
        expect(result.data[:tools].map { |tool| tool[:id] }).not_to include("dummy_admin_example")
      end
    end

    context "when the user is an audit operator" do
      subject(:result) { described_class.call(user: operator) }

      let(:operator) { create(:user, roles: ["audit_operator"]) }

      it "returns only the audit tool" do
        expect(result.data[:tools].map { |tool| tool[:id] }).to eq(%w[audit])
      end
    end

    context "when the user is a messaging operator" do
      subject(:result) { described_class.call(user: operator) }

      let(:operator) { create(:user, roles: ["messaging_operator"]) }

      it "returns only the messaging tool" do
        expect(result.data[:tools].map { |tool| tool[:id] }).to eq(%w[messaging])
      end
    end

    context "when the user is an operations admin" do
      subject(:result) { described_class.call(user: operator) }

      let(:operator) { create(:user, roles: ["operations_admin"]) }

      it "returns both CommandTower tools without the dummy host tool" do
        expect(result.data[:tools].map { |tool| tool[:id] }).to eq(%w[messaging users audit])
        expect(result.data[:tools].map { |tool| tool[:id] }).not_to include("dummy_admin_example")
      end
    end

    context "when the user is an owner" do
      subject(:result) { described_class.call(user: owner) }

      let(:owner) { create(:user, :role_owner) }

      it "includes CommandTower tools and the dummy host tool" do
        expect(result.data[:tools].map { |tool| tool[:id] }).to eq(%w[messaging users audit dummy_admin_example])
      end
    end

    context "when the user is a member" do
      subject(:result) { described_class.call(user: member) }

      let(:member) { create(:user, roles: ["member"]) }

      it "returns no tools" do
        expect(result.data[:tools]).to eq([])
      end
    end
  end
end
