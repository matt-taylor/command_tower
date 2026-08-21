# frozen_string_literal: true

RSpec.describe CommandTower::AdminScope::Resolve do
  describe ".call" do
    context "when the tool does not require scope" do
      subject(:result) { described_class.call(tool_id: "messaging", principal: create(:user), scope_value: nil) }

      it { expect(result).to be_nil }
    end

    context "when scope is required" do
      let(:admin) { create(:user, :role_admin) }
      let(:member_a) { create(:user, roles: ["member"]) }
      let(:member_b) { create(:user, roles: ["member"]) }

      before do
        register_foundation_proof_scoped_admin!
        seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
      end

      context "when scope_value is blank" do
        subject(:invoke) { described_class.call(tool_id: "users", principal: admin, scope_value: "  ") }

        it "raises ForbiddenError" do
          expect { invoke }.to raise_error(CommandTower::Errors::ForbiddenError)
        end
      end

      context "when scope_value is unauthorized" do
        subject(:invoke) { described_class.call(tool_id: "users", principal: admin, scope_value: "scope-z") }

        it "raises ForbiddenError" do
          expect { invoke }.to raise_error(CommandTower::Errors::ForbiddenError)
        end
      end

      context "when scope_value is authorized" do
        subject(:result) { described_class.call(tool_id: "users", principal: admin, scope_value: "scope-a") }

        it "returns a ScopeContext" do
          expect(result).to be_a(CommandTower::AdminScope::ScopeContext)
          expect(result.tool_id).to eq("users")
          expect(result.scope_value).to eq("scope-a")
          expect(result.scope_parameter).to eq("partition")
        end
      end
    end
  end
end
