# frozen_string_literal: true

RSpec.describe CommandTower::Events do
  after { CommandTower::Current.reset }

  describe ".instrument_name" do
    it "builds a structured command_tower name" do
      expect(described_class.instrument_name(category: :lifecycle, name: "workflow.started")).to eq(
        CommandTower::Events::WORKFLOW_STARTED
      )
    end

    context "when a segment is invalid" do
      subject(:invoke) { described_class.instrument_name(category: "Audit", name: :wager_transition) }

      it "raises" do
        expect { invoke }.to raise_error(ArgumentError, /invalid category/)
      end
    end
  end

  describe ".publish" do
    let(:recorded) { [] }
    let(:subscriber) { nil }

    after { unsubscribe_notifications(subscriber) if subscriber }

    context "when publishing a semantic event" do
      let(:subscriber) do
        events = recorded
        ActiveSupport::Notifications.subscribe("command_tower.audit.wager_transition") do |name, _s, _f, _id, payload|
          events << { name: name, payload: payload.dup }
        end
      end

      before do
        subscriber
        CommandTower::Current.execution_uuid = "exec-1"
        CommandTower::Current.correlation_id = "corr-1"
        CommandTower::Current.user_id = 44
        described_class.publish(
          category: :audit,
          name: :wager_transition,
          payload: { wager_id: 9, user: Object.new },
          subject: "Host::PlaceWagerWorkflow"
        )
      end

      it "uses the taxonomy name and Execution Context snapshot" do
        expect(recorded.size).to eq(1)
        expect(recorded.first[:name]).to eq("command_tower.audit.wager_transition")
        expect(recorded.first[:payload][:execution_uuid]).to eq("exec-1")
        expect(recorded.first[:payload][:correlation_id]).to eq("corr-1")
        expect(recorded.first[:payload][:user_id]).to eq(44)
        expect(recorded.first[:payload][:wager_id]).to eq(9)
        expect(recorded.first[:payload][:event_uuid]).to be_present
        expect(recorded.first[:payload]).not_to have_key(:user)
        expect(recorded.first[:payload][:subject]).to eq("Host::PlaceWagerWorkflow")
      end
    end

    context "when a subscriber raises" do
      let(:subscriber) do
        ActiveSupport::Notifications.subscribe("command_tower.metric.probe") do |*_args|
          raise StandardError, "subscriber boom"
        end
      end

      before { subscriber }

      subject(:invoke) { described_class.publish(category: :metric, name: :probe) }

      it "preserves Rails-native synchronous exception behavior" do
        expect { invoke }.to raise_error(StandardError, "subscriber boom")
      end
    end

    context "when Rails.logger is silenced" do
      let(:subscriber) do
        events = recorded
        ActiveSupport::Notifications.subscribe("command_tower.log.probe") do |name, *_rest|
          events << name
        end
      end

      before do
        subscriber
        Rails.logger.silence do
          described_class.publish(category: :log, name: :probe)
        end
      end

      it "still publishes" do
        expect(recorded).to eq(["command_tower.log.probe"])
      end
    end

    context "when the category is not a closed enum" do
      let(:subscriber) do
        events = recorded
        ActiveSupport::Notifications.subscribe("command_tower.host.custom_probe") do |name, *_rest|
          events << name
        end
      end

      before do
        subscriber
        described_class.publish(category: :host, name: :custom_probe)
      end

      it { expect(recorded).to eq(["command_tower.host.custom_probe"]) }
    end
  end

  describe ".snapshot" do
    let(:frozen) { described_class.snapshot }

    before do
      CommandTower::Current.execution_uuid = "live"
      frozen
      CommandTower::Current.execution_uuid = "later"
    end

    it { expect(frozen[:execution_uuid]).to eq("live") }
  end

  describe ".around_execution" do
    let(:recorded) { [] }
    let(:subscriber) do
      events = recorded
      ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\./) do |name, _s, _f, _id, payload|
        events << { name:, payload: payload.dup }
      end
    end

    after { unsubscribe_notifications(subscriber) }

    before do
      subscriber
      described_class.around_execution(layer: :workflow, subject: "QuietProbe", log_lifecycle: false) do |record|
        record[:result] = CommandTower::Workflows::WorkflowResult.success(payload: { ok: true }, http_status: :ok)
      end
    end

    it "emits the pair with log_lifecycle as subscriber guidance" do
      expect(recorded.map { |event| event[:name] }).to eq(
        [
          CommandTower::Events::WORKFLOW_STARTED,
          CommandTower::Events::WORKFLOW_COMPLETED
        ]
      )
      expect(recorded.last[:payload][:log_lifecycle]).to eq(false)
      expect(recorded.last[:payload][:outcome]).to eq(:success)
    end
  end
end
