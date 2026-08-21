# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Event, type: :model do
  subject(:event) { described_class.create!(**params) }

  let(:params) do
    {
      event_uuid:,
      action:,
      occurred_at:,
      execution_uuid: "exec-audit-event",
      correlation_id: "corr-audit-event",
      actor_user_id: 11,
      affected_user_id: 11,
      effective_user_id: 11,
      impersonation_active:,
      originating_administrator_id:,
      attribution_mode:,
      scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
      subject_type: "User",
      subject_id: 11,
      change_set:,
      metadata:,
      user_history:,
      sensitive_fields:,
      retention:
    }
  end
  let(:event_uuid) { "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }
  let(:action) { "password_changed" }
  let(:occurred_at) { Time.utc(2026, 8, 16, 12, 0, 0) }
  let(:impersonation_active) { false }
  let(:originating_administrator_id) { nil }
  let(:attribution_mode) { "self_service" }
  let(:change_set) { {} }
  let(:metadata) { {} }
  let(:user_history) { true }
  let(:sensitive_fields) { [] }
  let(:retention) { "permanent" }

  describe "persistence" do
    it "stores an append-only ledger row" do
      expect(event).to be_persisted
      expect(described_class.table_name).to eq("command_tower_audit_events")
      expect(event.event_uuid).to eq(event_uuid)
      expect(event.action).to eq(action)
      expect(event.attribution_mode).to eq(attribution_mode)
      expect(event.user_history).to eq(true)
      expect(event.retention).to eq("permanent")
    end
  end

  describe "validations" do
    context "when event_uuid is missing" do
      subject(:record) { described_class.new(**params.except(:event_uuid)) }

      it "is invalid" do
        expect(record).not_to be_valid
        expect(record.errors[:event_uuid]).to be_present
      end
    end

    context "when attribution_mode is unknown" do
      subject(:record) { described_class.new(**params.merge(attribution_mode: "other")) }

      it "is invalid" do
        expect(record).not_to be_valid
        expect(record.errors[:attribution_mode]).to be_present
      end
    end

    context "when impersonation is active without an originating administrator" do
      subject(:record) do
        described_class.new(
          **params.merge(impersonation_active: true, originating_administrator_id: nil, attribution_mode: "impersonation")
        )
      end

      it "is invalid" do
        expect(record).not_to be_valid
        expect(record.errors[:originating_administrator_id]).to be_present
      end
    end
  end

  describe "uniqueness" do
    before { described_class.create!(**params) }

    subject(:duplicate) { described_class.create!(**params.merge(action: "session_created")) }

    it "rejects a colliding event_uuid" do
      expect { duplicate }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "append-only" do
    let!(:record) { described_class.create!(**params) }

    context "when updating a persisted row" do
      subject(:mutate) { record.update!(action: "session_created") }

      it "raises" do
        expect { mutate }.to raise_error(CommandTower::Audit::ImmutableError)
      end
    end

    context "when destroying a persisted row" do
      subject(:mutate) { record.destroy }

      it "raises" do
        expect { mutate }.to raise_error(CommandTower::Audit::ImmutableError)
      end
    end
  end
end
