# frozen_string_literal: true

RSpec.describe "Admin Audit scoping", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member_a) { create(:user, roles: ["member"], email: "audit-a@example.com") }
  let(:member_b) { create(:user, roles: ["member"], email: "audit-b@example.com") }
  let(:headers) { authenticate_request_with_bearer!(admin) }

  before do
    register_foundation_proof_scoped_admin!
    seed_foundation_proof_partitions!(admin:, member_a:, member_b:)

    CommandTower::Audit::Event.create!(
      event_uuid: SecureRandom.uuid,
      action: "host.partition_action",
      occurred_at: Time.current,
      attribution_mode: "admin_direct",
      scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:host],
      host_context_type: FoundationProof::AdminScope::HOST_CONTEXT_TYPE,
      host_context_identifier: "scope-a",
      change_set: {},
      metadata: {},
      user_history: false,
      sensitive_fields: [],
      retention: "permanent"
    )

    CommandTower::Audit::Event.create!(
      event_uuid: SecureRandom.uuid,
      action: "user_registered",
      occurred_at: Time.current,
      attribution_mode: "self_service",
      scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
      affected_user_id: member_a.id,
      change_set: {},
      metadata: {},
      user_history: true,
      sensitive_fields: [],
      retention: "permanent"
    )

    CommandTower::Audit::Event.create!(
      event_uuid: SecureRandom.uuid,
      action: "session_created",
      occurred_at: Time.current,
      attribution_mode: "self_service",
      scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
      affected_user_id: member_a.id,
      change_set: {},
      metadata: {},
      user_history: true,
      sensitive_fields: [],
      retention: "permanent"
    )

    CommandTower::Audit::Event.create!(
      event_uuid: SecureRandom.uuid,
      action: "legacy_fact",
      occurred_at: Time.current,
      attribution_mode: "system",
      scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:legacy],
      affected_user_id: member_a.id,
      change_set: {},
      metadata: {},
      user_history: true,
      sensitive_fields: [],
      retention: "permanent"
    )
  end

  describe "GET /admin/audit-events" do
    context "when scoped to scope-a" do
      before { get "/admin/audit-events", params: { partition: "scope-a" }, headers: headers }

      subject(:event_names) do
        response.parsed_body.fetch("data").map { |row| row.fetch("eventName") }
      end

      it { expect(response).to have_http_status(:ok) }

      it "includes host-scoped events for scope-a" do
        expect(event_names).to include("host.partition_action")
      end

      it "includes eligible global events for in-scope users" do
        expect(event_names).to include("user_registered")
      end

      it "excludes ineligible global events" do
        expect(event_names).not_to include("session_created")
      end

      it "excludes legacy events" do
        expect(event_names).not_to include("legacy_fact")
      end
    end
  end
end
