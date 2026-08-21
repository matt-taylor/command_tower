# frozen_string_literal: true

RSpec.describe "nested workflow and service lifecycle" do
  after do
    unsubscribe_notifications(subscriber) if defined?(subscriber) && subscriber
    CommandTower::Current.reset
  end

  let(:recorded) { [] }
  let(:subscriber) do
    events = recorded
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle\./) do |name, _s, _f, _id, payload|
      events << { name: name, payload: payload.dup }
    end
  end

  let(:service_class) do
    Class.new(CommandTower::Services::ApplicationService) do
      def call
        context.uuid = execution_context.execution_uuid
      end
    end
  end

  let(:workflow_class) do
    nested = service_class
    Class.new(CommandTower::Workflows::ApplicationWorkflow) do
      retry_strategy :none

      define_method(:call) do |**|
        nested.call
        success(payload: { ok: true }, http_status: :ok)
      end
    end
  end

  before do
    stub_const("CommandTower::NestedLifecycleService", service_class)
    stub_const("CommandTower::NestedLifecycleWorkflow", workflow_class)
    subscriber
    CommandTower.with_execution(source: :console) { CommandTower::NestedLifecycleWorkflow.call }
  end

  let(:lifecycle_names) { recorded.map { |event| event[:name] } }
  let(:execution_uuids) { recorded.map { |event| event[:payload][:execution_uuid] }.uniq }

  it "emits independent lifecycle pairs that share execution_uuid" do
    expect(lifecycle_names).to eq(
      [
        CommandTower::Events::WORKFLOW_STARTED,
        CommandTower::Events::SERVICE_STARTED,
        CommandTower::Events::SERVICE_COMPLETED,
        CommandTower::Events::WORKFLOW_COMPLETED
      ]
    )
    expect(execution_uuids.size).to eq(1)
    expect(execution_uuids.first).to be_present
  end
end
