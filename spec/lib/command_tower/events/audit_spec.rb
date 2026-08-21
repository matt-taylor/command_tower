# frozen_string_literal: true

RSpec.describe CommandTower::Events do
  after do
    unsubscribe_notifications(subscriber) if defined?(subscriber) && subscriber
    CommandTower::Current.reset
  end

  describe ".publish_audit" do
    let(:recorded) { [] }
    let(:subscriber) do
      events = recorded
      ActiveSupport::Notifications.subscribe("command_tower.audit.role_assigned") do |name, _s, _f, _id, payload|
        events << { name: name, payload: payload.dup }
      end
    end

    context "when the envelope is structured" do
      before do
        subscriber
        CommandTower::Current.execution_uuid = "exec-1"
        described_class.publish_audit(
          name: :role_assigned,
          envelope: {
            action: "role_assigned",
            attribution_mode: :self_service,
            scope_class: "global",
            host_context_type: "foundation.partition",
            host_context_identifier: "alpha",
            changes: { "role" => { "from" => nil, "to" => "member" } },
            metadata: {}
          }
        )
      end

      it "forwards scope and host context fields" do
        expect(recorded.first[:payload][:scope_class]).to eq("global")
        expect(recorded.first[:payload][:host_context_type]).to eq("foundation.partition")
        expect(recorded.first[:payload][:host_context_identifier]).to eq("alpha")
      end

      it "does not run the scalar sanitizer against nested changes" do
        expect(recorded.first[:payload][:changes]).to eq("role" => { "from" => nil, "to" => "member" })
        expect(recorded.first[:payload][:execution_uuid]).to eq("exec-1")
        expect(recorded.first[:payload][:event_uuid]).to be_present
      end
    end
  end

  describe ".sanitize_payload" do
    context "when the payload contains a nested hash" do
      subject(:result) { described_class.sanitize_payload({ wager_id: 9, changes: { role: { from: nil, to: "x" } } }) }

      it "still drops nested hashes" do
        expect(result).to eq(wager_id: 9)
      end
    end
  end
end
