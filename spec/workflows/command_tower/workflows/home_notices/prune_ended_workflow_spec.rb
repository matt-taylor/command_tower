# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::HomeNotices::PruneEndedWorkflow do
  subject(:result) { described_class.call }

  it "returns the number of rows pruned", :aggregate_failures do
    expect(result).to be_success
    expect(result.payload).to eq(deleted: 0)
  end

  it "runs from the job" do
    expect { CommandTower::HomeNotices::PruneEndedJob.perform_now }.not_to raise_error
  end
end
