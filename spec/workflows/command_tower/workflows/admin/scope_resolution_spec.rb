# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Admin::ScopeResolution do
  describe ".resolve" do
    let(:admin) { create(:user, :role_admin) }
    let(:member_a) { create(:user, roles: ["member"]) }
    let(:member_b) { create(:user, roles: ["member"]) }

    before do
      register_foundation_proof_scoped_admin!
      seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
    end

    context "when scope_value is missing for a scoped tool" do
      subject(:result) { described_class.resolve(tool_id: "users", user: admin, scope_value: nil) }

      it { expect(result).to be_failure }

      it "maps to forbidden" do
        expect(result.http_status).to eq(:forbidden)
      end
    end

    context "when scope_value is authorized" do
      subject(:result) { described_class.resolve(tool_id: "users", user: admin, scope_value: "scope-a") }

      it "returns a ScopeContext" do
        expect(result).to be_a(CommandTower::AdminScope::ScopeContext)
        expect(result.scope_value).to eq("scope-a")
      end
    end
  end
end
