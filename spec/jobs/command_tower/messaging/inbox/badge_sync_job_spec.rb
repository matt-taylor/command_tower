# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Inbox::BadgeSyncJob do
  before do
    allow(CommandTower::Workflows::Messaging::Inbox::SyncAppIconBadgeWorkflow).to receive(:call_from_job)
  end

  it "runs the workflow with the user id only" do
    described_class.perform_now(42)

    expect(CommandTower::Workflows::Messaging::Inbox::SyncAppIconBadgeWorkflow)
      .to have_received(:call_from_job).with(job: instance_of(described_class), user_id: 42)
  end
end
