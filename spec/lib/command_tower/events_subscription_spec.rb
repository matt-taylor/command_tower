# frozen_string_literal: true

RSpec.describe "lifecycle subscription" do
  after do
    unsubscribe_notifications(exact_subscriber)
    unsubscribe_notifications(broad_subscriber)
    unsubscribe_notifications(unrelated_subscriber)
  end

  let(:exact) { [] }
  let(:broad) { [] }
  let(:unrelated) { [] }

  let(:exact_subscriber) do
    bucket = exact
    ActiveSupport::Notifications.subscribe(CommandTower::Events::WORKFLOW_COMPLETED) do |name, *_rest|
      bucket << name
    end
  end

  let(:broad_subscriber) do
    bucket = broad
    ActiveSupport::Notifications.subscribe(/\Acommand_tower\.lifecycle(?:\.|\z)/) do |name, *_rest|
      bucket << name
    end
  end

  let(:unrelated_subscriber) do
    bucket = unrelated
    ActiveSupport::Notifications.subscribe("command_tower.audit.wager_transition") do |name, *_rest|
      bucket << name
    end
  end

  let(:workflow_class) do
    Class.new(CommandTower::Workflows::ApplicationWorkflow) do
      retry_strategy :none

      def call(**)
        success(payload: { ok: true }, http_status: :ok)
      end
    end
  end

  before do
    stub_const("CommandTower::SubscriptionProbeWorkflow", workflow_class)
    exact_subscriber
    broad_subscriber
    unrelated_subscriber
    CommandTower::SubscriptionProbeWorkflow.call
  end

  it "supports exact and broad lifecycle subscription without notifying unrelated categories" do
    expect(exact).to eq([CommandTower::Events::WORKFLOW_COMPLETED])
    expect(broad).to eq(
      [
        CommandTower::Events::WORKFLOW_STARTED,
        CommandTower::Events::WORKFLOW_COMPLETED
      ]
    )
    expect(unrelated).to eq([])
  end
end
