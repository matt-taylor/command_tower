# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Persistence::Subscriber do
  after do
    CommandTower::Current.reset
    described_class.attach!
  end

  describe ".attach!" do
    before do
      described_class.attach!
      described_class.attach!
    end

    it "keeps a single subscription" do
      expect(described_class.subscriptions.size).to eq(1)
    end
  end

  describe "#call" do
    let(:user) { create(:user) }

    context "when a registered fact is emitted" do
      before do
        described_class.attach!
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::Audit::Emit.call(
            name: :password_changed,
            subject: user,
            affected_user: user,
            changes: {},
            scope_class: :global
          )
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "password_changed") }

      it "inserts a ledger row with a policy snapshot" do
        expect(row.affected_user_id).to eq(user.id)
        expect(row.actor_user_id).to eq(user.id)
        expect(row.attribution_mode).to eq("self_service")
        expect(row.subject_type).to eq("User")
        expect(row.subject_id).to eq(user.id)
        expect(row.user_history).to eq(true)
        expect(row.sensitive_fields).to eq([])
        expect(row.retention).to eq("permanent")
        expect(row.change_set).to eq({})
      end
    end

    context "when the registered event is session_created" do
      before do
        described_class.attach!
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::Audit::Emit.call(name: :session_created, affected_user: user, changes: {}, scope_class: :global)
        end
      end

      let(:row) { CommandTower::Audit::Event.find_by!(action: "session_created") }

      it "snapshots user_history and retention from the current definition" do
        expect(row.user_history).to eq(false)
        expect(row.retention).to eq("ninety_days")
      end
    end

    context "when the registered event is disabled" do
      before do
        described_class.attach!
        CommandTower.config.registry.audit.event :noisy_session do |event|
          event.enabled = false
          event.affected_user_required = false
        end
        CommandTower::Audit::Emit.call(name: :noisy_session, scope_class: :global)
      end

      it "does not insert a row" do
        expect(CommandTower::Audit::Event.where(action: "noisy_session")).to eq([])
      end
    end
  end

  describe "standalone persistence" do
    before { described_class.attach! }

    let(:user) { create(:user) }

    context "when audit is emitted without a business transaction" do
      before { result }

      let(:row) { CommandTower::Audit::Event.find_by!(action: "session_created", affected_user_id: user.id) }

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditProbeWorkflow.call(
            name: :session_created,
            affected_user: user,
            changes: {}
          )
        end
      end

      it "persists the fact synchronously without requiring a surrounding transaction" do
        expect(result).to be_success
        expect(row).to be_persisted
        expect(row.affected_user_id).to eq(user.id)
      end
    end
  end

  describe "transaction participation" do
    before { described_class.attach! }

    let(:user) { create(:user) }
    let(:original_email) { user.email }
    let(:new_email) { "changed-#{SecureRandom.hex(4)}@example.com" }

    context "when the workflow commits" do
      before { original_email }

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditTransactionalWorkflow.call(
            user:,
            email: new_email,
            name: :password_changed,
            changes: {}
          )
        end
      end

      it "commits the mutation and the audit row together" do
        expect(result).to be_success
        expect(user.reload.email).to eq(new_email)
        expect(CommandTower::Audit::Event.find_by!(action: "password_changed").affected_user_id).to eq(user.id)
      end
    end

    context "when the workflow raises after audit" do
      before { original_email }

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditTransactionalThenRaiseWorkflow.call(
            user:,
            email: new_email,
            name: :password_changed,
            changes: {}
          )
        end
      end

      it "rolls back the mutation and the audit row" do
        expect(result).to be_failure
        expect(user.reload.email).to eq(original_email)
        expect(CommandTower::Audit::Event.where(action: "password_changed")).to eq([])
      end
    end

    context "when persistence hits a unique event_uuid collision" do
      let(:collision_uuid) { "11111111-1111-4111-8111-111111111111" }

      before do
        original_email
        allow(SecureRandom).to receive(:uuid).and_return(collision_uuid)
      end

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditTwiceTransactionalWorkflow.call(user:, email: new_email)
        end
      end

      it "fails audit persistence and rolls back the mutation" do
        expect(result).to be_failure
        expect(user.reload.email).to eq(original_email)
        expect(CommandTower::Audit::Event.where(event_uuid: collision_uuid)).to eq([])
      end
    end

    context "when one transaction emits many facts" do
      before { original_email }

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditManyFactsTransactionalWorkflow.call(
            user:,
            email: new_email,
            facts: [
              { name: :user_registered, subject: user, affected_user: user, changes: {} },
              { name: :role_assigned, subject: user, affected_user: user, changes: { role: { from: nil, to: "member" } } }
            ]
          )
        end
      end

      it "commits every fact with the mutation" do
        expect(result).to be_success
        expect(user.reload.email).to eq(new_email)
        expect(CommandTower::Audit::Event.where(affected_user_id: user.id).pluck(:action)).to contain_exactly(
          "user_registered",
          "role_assigned"
        )
      end
    end

    context "when a nested service audits inside the outer workflow transaction" do
      before { original_email }

      subject(:result) do
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditNestedServiceTransactionalWorkflow.call(
            user:,
            email: new_email,
            name: :password_changed,
            changes: {}
          )
        end
      end

      it "commits the service audit with the workflow mutation" do
        expect(result).to be_success
        expect(user.reload.email).to eq(new_email)
        expect(CommandTower::Audit::Event.find_by!(action: "password_changed").affected_user_id).to eq(user.id)
      end
    end
  end
end
