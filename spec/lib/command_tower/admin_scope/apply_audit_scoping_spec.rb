# frozen_string_literal: true

RSpec.describe CommandTower::AdminScope::ApplyAuditScoping do
  describe ".call" do
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
    let(:base_relation) { CommandTower::Audit::Event.order(occurred_at: :desc, id: :desc) }
    let!(:host_event) do
      create_audit_event!(
        action: "host.partition_action",
        scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:host],
        host_context_type: FoundationProof::AdminScope::HOST_CONTEXT_TYPE,
        host_context_identifier: "scope-a"
      )
    end
    let!(:global_event) do
      create_audit_event!(
        action: "user_registered",
        scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
        affected_user_id: member_a.id
      )
    end
    let!(:ineligible) do
      create_audit_event!(
        action: "session_created",
        scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
        affected_user_id: member_a.id
      )
    end
    let!(:legacy) do
      create_audit_event!(
        action: "legacy_fact",
        scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:legacy],
        affected_user_id: member_a.id
      )
    end

    before { register_foundation_proof_scoped_admin! }

    before { seed_foundation_proof_partitions!(admin:, member_a:, member_b:) }

    subject(:scoped_ids) do
      described_class.call(relation: base_relation, scope_context:, principal: admin).pluck(:id)
    end

    it "includes host-scoped events for the partition" do
      expect(scoped_ids).to include(host_event.id)
    end

    it "includes eligible global events for in-scope users" do
      expect(scoped_ids).to include(global_event.id)
    end

    it "excludes ineligible global events" do
      expect(scoped_ids).not_to include(ineligible.id)
    end

    it "excludes legacy events" do
      expect(scoped_ids).not_to include(legacy.id)
    end
  end
end
