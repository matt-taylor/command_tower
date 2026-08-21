# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::ApplicationWorkflow do
  after do
    unsubscribe_notifications(subscriber) if defined?(subscriber) && subscriber
    CommandTower::Current.reset
  end

  let(:recorded) { [] }
  let(:subscriber) do
    events = recorded
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\.workflow/) do |name, _s, _f, _id, payload|
      events << { name: name, payload: payload.dup }
    end
  end

  let(:workflow_class) do
    Class.new(described_class) do
      retry_strategy :none

      def call(**)
        success(payload: { ok: true }, http_status: :ok)
      end
    end
  end

  before { stub_const("CommandTower::LifecycleProbeWorkflow", workflow_class) }

  describe ".call" do
    context "when the workflow succeeds" do
      before do
        subscriber
        CommandTower.with_execution(source: :rake, user_id: 7, correlation_id: "corr-w") do
          CommandTower::Current.request_id = "req-w"
          CommandTower::LifecycleProbeWorkflow.call
        end
      end

      it "emits exactly one started/completed pair" do
        expect(recorded.map { |event| event[:name] }).to eq(
          [
            CommandTower::Events::WORKFLOW_STARTED,
            CommandTower::Events::WORKFLOW_COMPLETED
          ]
        )
      end

      it "snapshots Execution Context and success outcome" do
        expect(recorded.last[:payload][:layer]).to eq(:workflow)
        expect(recorded.last[:payload][:subject]).to eq("CommandTower::LifecycleProbeWorkflow")
        expect(recorded.last[:payload][:outcome]).to eq(:success)
        expect(recorded.last[:payload][:duration_ms]).to be_a(Numeric)
        expect(recorded.last[:payload][:execution_uuid]).to be_present
        expect(recorded.last[:payload][:correlation_id]).to eq("corr-w")
        expect(recorded.last[:payload][:request_id]).to eq("req-w")
        expect(recorded.last[:payload][:source]).to eq(:rake)
        expect(recorded.last[:payload][:user_id]).to eq(7)
        expect(recorded.last[:payload][:event_uuid]).to be_present
      end
    end

    context "when the workflow fails" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            failure(errors: [CommandTower::Errors::UnauthorizedError.new], http_status: :unauthorized)
          end
        end
      end

      before do
        subscriber
        CommandTower::LifecycleProbeWorkflow.call
      end

      it "records failure outcome and error codes" do
        expect(recorded.last[:payload][:outcome]).to eq(:failure)
        expect(recorded.last[:payload][:error_codes]).to eq(["unauthorized"])
      end
    end

    context "when the workflow defers" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :delayed_continuation, max_attempts: 3

          def call(**)
            deferred(reason: :provider_cooldown, retry_after: 5)
          end
        end
      end

      before do
        subscriber
        CommandTower::LifecycleProbeWorkflow.call
      end

      it { expect(recorded.last[:payload][:outcome]).to eq(:deferred) }
    end

    context "when a lifecycle subscriber raises" do
      let(:subscriber) do
        ActiveSupport::Notifications.subscribe(CommandTower::Events::WORKFLOW_STARTED) do |*_args|
          raise StandardError, "lifecycle subscriber boom"
        end
      end

      before { subscriber }

      subject(:invoke) { CommandTower::LifecycleProbeWorkflow.call }

      it "does not swallow the subscriber exception into InternalError" do
        expect { invoke }.to raise_error(StandardError, "lifecycle subscriber boom")
      end
    end

    context "when publish_event is used from a workflow" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            publish_event(category: :audit, name: :wager_transition, payload: { wager_id: 3 })
            success(payload: { ok: true }, http_status: :ok)
          end
        end
      end

      let(:semantic) { [] }
      let(:semantic_subscriber) do
        bucket = semantic
        ActiveSupport::Notifications.subscribe("command_tower.audit.wager_transition") do |_n, _s, _f, _id, payload|
          bucket << payload.dup
        end
      end

      before do
        subscriber
        semantic_subscriber
        CommandTower.with_execution(source: :console) { CommandTower::LifecycleProbeWorkflow.call }
      end

      after { unsubscribe_notifications(semantic_subscriber) }

      it "enriches the semantic event from Execution Context" do
        expect(semantic.first[:wager_id]).to eq(3)
        expect(semantic.first[:execution_uuid]).to be_present
        expect(semantic.first[:source]).to eq(:console)
        expect(semantic.first[:subject]).to eq("CommandTower::LifecycleProbeWorkflow")
      end
    end

    context "when an unexpected exception is raised" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            raise StandardError, "boom"
          end
        end
      end

      before do
        allow(Rails.logger).to receive(:error)
        subscriber
        CommandTower::LifecycleProbeWorkflow.call
      end

      it "returns InternalError and emits error outcome" do
        expect(recorded.last[:payload][:outcome]).to eq(:error)
        expect(recorded.last[:payload][:error_class]).to eq("StandardError")
      end
    end
  end

  describe ".call_from_job" do
    context "when an unexpected exception is raised" do
      let(:workflow_class) do
        Class.new(described_class) do
          retry_strategy :none

          def call(**)
            raise StandardError, "job boom"
          end
        end
      end

      before { subscriber }

      subject(:invoke) { CommandTower::LifecycleProbeWorkflow.call_from_job }

      it "re-raises after emitting completed error" do
        expect { invoke }.to raise_error(StandardError, "job boom")
        expect(recorded.last[:payload][:outcome]).to eq(:error)
      end
    end
  end
end
