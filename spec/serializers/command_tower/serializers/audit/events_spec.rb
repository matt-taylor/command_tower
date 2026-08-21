# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Audit::Events::EventSerializer do
  subject(:payload) do
    described_class.serialize(
      {
        id: 9,
        event_name: "phone_updated",
        event_label: "Phone updated",
        occurred_at: Time.utc(2026, 8, 16, 12, 0, 0),
        attribution_mode: "self_service",
        actor_user_id: 11,
        affected_user_id: 11,
        subject_type: "User",
        subject_id: 11,
        subject_label: "member",
        impersonation_active: false,
        originating_administrator_id: nil,
        changes: { "phone" => { "from" => "*******1212", "to" => nil } },
        metadata: { "reason" => "user_request" }
      }
    )
  end

  it "emits camelCase fields from a projection hash" do
    expect(payload).to include(
      id: 9,
      eventName: "phone_updated",
      eventLabel: "Phone updated",
      attributionMode: "self_service",
      actor: { userId: 11 },
      affectedUser: { userId: 11 },
      subject: { type: "User", id: 11, label: "member" },
      impersonationActive: false,
      originatingAdministratorId: nil,
      changes: { "phone" => { "from" => "*******1212", "to" => nil } },
      metadata: { "reason" => "user_request" }
    )
    expect(payload[:occurredAt]).to eq("2026-08-16T12:00:00Z")
  end
end
