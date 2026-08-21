# frozen_string_literal: true

RSpec.describe CommandTower::Services::Audit::Events::List do
  let(:owner_id) { 101 }
  let(:other_id) { 202 }

  describe ".call" do
    let!(:visible) do
      create_audit_event!(
        affected_user_id: owner_id,
        actor_user_id: owner_id,
        action: "password_changed",
        occurred_at: Time.utc(2026, 8, 16, 12, 0, 2),
        user_history: true
      )
    end
    let!(:hidden_history) do
      create_audit_event!(
        affected_user_id: owner_id,
        actor_user_id: owner_id,
        action: "session_created",
        occurred_at: Time.utc(2026, 8, 16, 12, 0, 3),
        user_history: false
      )
    end
    let!(:other_user) do
      create_audit_event!(
        affected_user_id: other_id,
        actor_user_id: owner_id,
        action: "role_assigned",
        occurred_at: Time.utc(2026, 8, 16, 12, 0, 4),
        user_history: true
      )
    end
    let!(:older) do
      create_audit_event!(
        affected_user_id: owner_id,
        actor_user_id: owner_id,
        action: "email_verified",
        occurred_at: Time.utc(2026, 8, 16, 12, 0, 1),
        user_history: true
      )
    end

    context "when viewer_scope is user" do
      subject(:result) do
        described_class.call(viewer_scope: :user, affected_user_id: owner_id, limit: 50, offset: 0)
      end

      it { expect(result).to be_success }

      it "returns only the caller's user_history rows" do
        expect(result.data[:events].map(&:id)).to eq([visible.id, older.id])
      end

      it "does not grant visibility from actor identity" do
        expect(result.data[:events].map(&:id)).not_to include(other_user.id)
      end

      it "hides snapshot user_history false rows" do
        expect(result.data[:events].map(&:id)).not_to include(hidden_history.id)
      end

      it "reports total_count for the scoped relation" do
        expect(result.data[:pagination]).to eq(limit: 50, offset: 0, total_count: 2)
      end
    end

    context "when the user scope is missing affected_user_id" do
      subject(:result) { described_class.call(viewer_scope: :user, limit: 10, offset: 0) }

      it { expect(result).not_to be_success }
    end

    context "when viewer_scope is admin" do
      subject(:result) { described_class.call(viewer_scope: :admin, limit: 50, offset: 0) }

      it { expect(result).to be_success }

      it "returns the full ledger including user_history false" do
        expect(result.data[:events].map(&:id)).to eq([other_user.id, hidden_history.id, visible.id, older.id])
      end
    end

    context "when paging" do
      subject(:result) do
        described_class.call(viewer_scope: :admin, limit: 1, offset: 1)
      end

      it "returns a bounded page" do
        expect(result.data[:events].map(&:id)).to eq([hidden_history.id])
        expect(result.data[:pagination]).to eq(limit: 1, offset: 1, total_count: 4)
      end
    end

    context "when filtering by action and time" do
      subject(:result) do
        described_class.call(
          viewer_scope: :user,
          affected_user_id: owner_id,
          actions: ["password_changed"],
          occurred_after: Time.utc(2026, 8, 16, 12, 0, 1),
          occurred_before: Time.utc(2026, 8, 16, 12, 0, 3),
          limit: 50,
          offset: 0
        )
      end

      it "applies present filters inside the user scope" do
        expect(result.data[:events].map(&:id)).to eq([visible.id])
      end
    end

    context "when an admin filters by affected user" do
      subject(:result) do
        described_class.call(viewer_scope: :admin, affected_user_id: other_id, limit: 50, offset: 0)
      end

      it "returns that user's rows including those the user cannot see" do
        expect(result.data[:events].map(&:id)).to eq([other_user.id])
      end
    end

    context "when admin scope_context narrows the ledger" do
      subject(:result) do
        described_class.call(
          viewer_scope: :admin,
          limit: 50,
          offset: 0,
          principal: admin,
          scope_context:
        )
      end

      let(:admin) { create(:user, :role_admin) }
      let(:member_a) { create(:user, roles: ["member"]) }
      let(:member_b) { create(:user, roles: ["member"]) }
      let(:scope_context) do
        CommandTower::AdminScope::ScopeContext.new(
          tool_id: "audit",
          scope_value: "scope-a",
          scope_parameter: "partition"
        )
      end
      let!(:host_scoped) do
        create_audit_event!(
          action: "host.partition_action",
          scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:host],
          host_context_type: FoundationProof::AdminScope::HOST_CONTEXT_TYPE,
          host_context_identifier: "scope-a"
        )
      end
      let!(:eligible_global) do
        create_audit_event!(
          action: "user_registered",
          scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
          affected_user_id: member_a.id,
          occurred_at: Time.utc(2026, 8, 16, 12, 0, 5)
        )
      end

      before do
        register_foundation_proof_scoped_admin!
        seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
      end

      it "includes host-scoped and eligible global events only" do
        expect(result.data[:events].map(&:id)).to include(host_scoped.id, eligible_global.id)
        expect(result.data[:events].map(&:id)).not_to include(other_user.id)
      end
    end

    context "when filtering by multiple actions" do
      subject(:result) do
        described_class.call(
          viewer_scope: :admin,
          actions: %w[password_changed session_created],
          limit: 50,
          offset: 0
        )
      end

      it "returns matching rows via IN" do
        expect(result.data[:events].map(&:action).uniq.sort).to eq(%w[password_changed session_created])
      end
    end
  end
end
