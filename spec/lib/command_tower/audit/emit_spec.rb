# frozen_string_literal: true

RSpec.describe CommandTower::Audit::Emit do
  after do
    unsubscribe_notifications(subscriber) if defined?(subscriber) && subscriber
    CommandTower::Current.reset
  end

  let(:recorded) { [] }
  let(:subscriber) do
    events = recorded
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.audit(?:\.|\z)/) do |name, _s, _f, _id, payload|
      events << { name: name, payload: payload.dup }
    end
  end
  let(:user) { create(:user) }

  describe ".call" do
    context "when a registered self-service fact is emitted" do
      before do
        subscriber
        CommandTower::Current.user_id = user.id
        CommandTower::Current.effective_user_id = user.id
        CommandTower::Current.source = :http
        CommandTower::Current.execution_uuid = "exec-audit"
        CommandTower::Current.correlation_id = "corr-audit"
        described_class.call(
          name: :role_assigned,
          subject: user,
          affected_user: user,
          changes: { role: { from: nil, to: "member" } }
        )
      end

      it "emits the registered instrument name" do
        expect(recorded.size).to eq(1)
        expect(recorded.first[:name]).to eq("command_tower.audit.role_assigned")
      end

      it "includes the structured envelope" do
        expect(recorded.first[:payload][:action]).to eq("role_assigned")
        expect(recorded.first[:payload][:event_uuid]).to be_present
        expect(recorded.first[:payload][:execution_uuid]).to eq("exec-audit")
        expect(recorded.first[:payload][:correlation_id]).to eq("corr-audit")
        expect(recorded.first[:payload][:source]).to eq(:http)
        expect(recorded.first[:payload][:subject_type]).to eq("User")
        expect(recorded.first[:payload][:subject_id]).to eq(user.id)
        expect(recorded.first[:payload][:affected_user_id]).to eq(user.id)
        expect(recorded.first[:payload][:actor_user_id]).to eq(user.id)
        expect(recorded.first[:payload][:attribution_mode]).to eq(:self_service)
        expect(recorded.first[:payload][:changes]).to eq("role" => { "from" => nil, "to" => "member" })
      end
    end

    context "when the event is unregistered" do
      subject(:invoke) { described_class.call(name: :not_registered, affected_user: user) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::UnregisteredEventError)
      end
    end

    context "when the registered event is disabled" do
      before do
        subscriber
        CommandTower.config.registry.audit.event :noisy_session do |event|
          event.enabled = false
          event.affected_user_required = false
        end
        described_class.call(name: :noisy_session)
      end

      it "does not emit" do
        expect(recorded).to eq([])
      end
    end

    context "when a required subject is missing" do
      before do
        CommandTower::Current.user_id = user.id
      end

      subject(:invoke) { described_class.call(name: :password_changed, affected_user: user, changes: {}) }

      it "raises" do
        expect { invoke }.to raise_error(CommandTower::Audit::MissingSubjectError)
      end
    end

    context "when affected user is independent from subject" do
      let(:other) { create(:user) }

      before do
        subscriber
        CommandTower::Current.user_id = user.id
        CommandTower::Current.effective_user_id = user.id
        described_class.call(
          name: :role_assigned,
          subject: other,
          affected_user: user,
          changes: { role: { from: nil, to: "member" } }
        )
      end

      it "snapshots the subject separately" do
        expect(recorded.first[:payload][:subject_id]).to eq(other.id)
        expect(recorded.first[:payload][:affected_user_id]).to eq(user.id)
      end
    end

    context "when empty changes are allowed" do
      before do
        subscriber
        CommandTower::Current.user_id = user.id
        described_class.call(name: :password_changed, subject: user, affected_user: user, changes: {})
      end

      it "emits an empty changes hash" do
        expect(recorded.first[:payload][:changes]).to eq({})
      end
    end

    context "when metadata is valid" do
      before do
        subscriber
        CommandTower::Current.user_id = user.id
        described_class.call(
          name: :password_changed,
          subject: user,
          affected_user: user,
          changes: {},
          metadata: { reason: "rotation" }
        )
      end

      it "preserves metadata" do
        expect(recorded.first[:payload][:metadata]).to eq("reason" => "rotation")
      end
    end
  end
end
