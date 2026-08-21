# frozen_string_literal: true

RSpec.describe CommandTower::Services::ApplicationService do
  after do
    unsubscribe_notifications(subscriber) if defined?(subscriber) && subscriber
    CommandTower::Current.reset
  end

  let(:recorded) { [] }
  let(:subscriber) do
    events = recorded
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\.service/) do |name, _s, _f, _id, payload|
      events << { name: name, payload: payload.dup }
    end
  end

  let(:service_class) do
    Class.new(described_class) do
      def call
        context.value = "ok"
      end
    end
  end

  before { stub_const("CommandTower::LifecycleProbeService", service_class) }

  describe ".call" do
    context "when the service succeeds" do
      before do
        subscriber
        CommandTower.with_execution(source: :job) { CommandTower::LifecycleProbeService.call }
      end

      it "emits exactly one started/completed pair" do
        expect(recorded.map { |event| event[:name] }).to eq(
          [
            CommandTower::Events::SERVICE_STARTED,
            CommandTower::Events::SERVICE_COMPLETED
          ]
        )
      end

      it "snapshots Execution Context and success outcome" do
        expect(recorded.last[:payload][:layer]).to eq(:service)
        expect(recorded.last[:payload][:subject]).to eq("CommandTower::LifecycleProbeService")
        expect(recorded.last[:payload][:outcome]).to eq(:success)
        expect(recorded.last[:payload][:source]).to eq(:job)
        expect(recorded.last[:payload][:execution_uuid]).to be_present
      end
    end

    context "when the service fails" do
      let(:service_class) do
        Class.new(described_class) do
          def call
            context.fail!(application_error: CommandTower::Errors::UnauthorizedError.new)
          end
        end
      end

      before do
        subscriber
        CommandTower::LifecycleProbeService.call
      end

      it "records failure outcome" do
        expect(recorded.last[:payload][:outcome]).to eq(:failure)
        expect(recorded.last[:payload][:error_codes]).to eq(["unauthorized"])
      end
    end

    context "when an unexpected exception is raised" do
      let(:service_class) do
        Class.new(described_class) do
          def call
            raise StandardError, "service boom"
          end
        end
      end

      before { subscriber }

      subject(:invoke) { CommandTower::LifecycleProbeService.call }

      it "re-raises after emitting completed error" do
        expect { invoke }.to raise_error(StandardError, "service boom")
        expect(recorded.last[:payload][:outcome]).to eq(:error)
        expect(recorded.last[:payload][:error_class]).to eq("StandardError")
      end
    end
  end
end
