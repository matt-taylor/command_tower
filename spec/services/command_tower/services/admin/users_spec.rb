# frozen_string_literal: true

RSpec.describe CommandTower::Services::Admin::Users::List do
  describe ".call" do
    subject(:result) { described_class.call(limit: 50, offset: 0, search:) }

    let(:search) { nil }
    let!(:alpha) { create(:user, email: "alpha@example.com", username: "alpha_user", first_name: "Alpha") }
    let!(:beta) { create(:user, email: "beta@example.com", username: "beta_user", last_name: "Beta") }

    it { expect(result).to be_success }

    it "returns users newest-id-first with pagination" do
      expect(result.data[:users].map(&:id)).to eq([beta.id, alpha.id].sort.reverse)
      expect(result.data[:pagination]).to include(limit: 50, offset: 0, total_count: 2)
    end

    context "when searching by username fragment" do
      let(:search) { "beta_u" }

      it "filters server-side" do
        expect(result.data[:users].map(&:id)).to eq([beta.id])
        expect(result.data[:pagination][:total_count]).to eq(1)
      end
    end

    context "when scoped to a partition" do
      subject(:result) do
        described_class.call(
          limit: 50,
          offset: 0,
          principal: admin,
          scope_context:
        )
      end

      let(:admin) { create(:user, :role_admin) }
      let(:member_a) { create(:user, roles: ["member"], username: "scoped_a") }
      let(:member_b) { create(:user, roles: ["member"], username: "scoped_b") }
      let(:scope_context) do
        CommandTower::AdminScope::ScopeContext.new(
          tool_id: "users",
          scope_value: "scope-a",
          scope_parameter: "partition"
        )
      end

      before do
        register_foundation_proof_scoped_admin!
        seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
      end

      it "narrows before pagination and count" do
        expect(result.data[:users].map(&:id)).to include(admin.id, member_a.id)
        expect(result.data[:users].map(&:id)).not_to include(member_b.id)
        expect(result.data[:pagination][:total_count]).to eq(2)
      end
    end
  end
end

RSpec.describe CommandTower::Services::Admin::Users::Show do
  describe ".call" do
    context "when the user exists" do
      subject(:result) { described_class.call(id: user.id) }

      let(:user) { create(:user) }

      it { expect(result).to be_success }

      it "returns the user" do
        expect(result.data[:user].id).to eq(user.id)
      end
    end

    context "when the user is missing" do
      subject(:result) { described_class.call(id: 0) }

      it { expect(result).to be_failure }

      it "fails with NotFoundError" do
        expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError)
      end
    end

    context "when the user is outside the scoped partition" do
      subject(:result) do
        described_class.call(
          id: member_b.id,
          principal: admin,
          scope_context:
        )
      end

      let(:admin) { create(:user, :role_admin) }
      let(:member_a) { create(:user, roles: ["member"]) }
      let(:member_b) { create(:user, roles: ["member"]) }
      let(:scope_context) do
        CommandTower::AdminScope::ScopeContext.new(
          tool_id: "users",
          scope_value: "scope-a",
          scope_parameter: "partition"
        )
      end

      before do
        register_foundation_proof_scoped_admin!
        seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
      end

      it { expect(result).to be_failure }

      it "fails with NotFoundError" do
        expect(result.errors.first).to be_a(CommandTower::Errors::NotFoundError)
      end
    end
  end
end
