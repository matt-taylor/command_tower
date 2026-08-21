# frozen_string_literal: true

RSpec.describe CommandTower::Execution::ContextAccess do
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

  describe "#audit" do
    context "when called from a workflow" do
      before do
        subscriber
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditProbeWorkflow.call(
            name: :password_changed,
            subject: user,
            affected_user: user,
            changes: {}
          )
        end
      end

      it "emits a semantic audit event without a second bus" do
        expect(recorded.map { |event| event[:name] }).to eq(["command_tower.audit.password_changed"])
      end
    end

    context "when called from a service" do
      before do
        subscriber
        CommandTower.with_execution(source: :job, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditProbeService.call(
            audit_name: :password_changed,
            audit_kwargs: { subject: user, affected_user: user, changes: {} }
          )
        end
      end

      it "emits on the same audit category" do
        expect(recorded.map { |event| event[:name] }).to eq(["command_tower.audit.password_changed"])
      end
    end

    context "when one workflow emits many facts" do
      before do
        subscriber
        CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
          CommandTower::AuditManyFactsWorkflow.call(
            facts: [
              { name: :user_registered, subject: user, affected_user: user, changes: {} },
              { name: :role_assigned, subject: user, affected_user: user, changes: { role: { from: nil, to: "member" } } }
            ]
          )
        end
      end

      it "emits each registered fact" do
        expect(recorded.map { |event| event[:name] }).to eq(
          [
            "command_tower.audit.user_registered",
            "command_tower.audit.role_assigned"
          ]
        )
      end
    end
  end
end
