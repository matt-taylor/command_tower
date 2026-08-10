# frozen_string_literal: true

RSpec.describe "Messaging job workflow cutover architecture" do
  let(:job_source) { ->(relative) { File.read(CommandTower::Engine.root.join(relative)) } }

  context "HandoffJob" do
    let(:source) { job_source.call("app/jobs/command_tower/messaging/handoff_job.rb") }

    it "invokes ProcessWorkflow via call_from_job" do
      expect(source).to include("ProcessWorkflow.call_from_job")
      expect(source).not_to include("Handoff::Workflow.call")
    end
  end

  context "ChannelDeliveryExecutionJob" do
    let(:source) { job_source.call("app/jobs/command_tower/messaging/channel_delivery_execution_job.rb") }
    let(:code_without_comments) { source.gsub(/^\s*#.*$/, "") }

    it "invokes DeliverWorkflow via call_from_job" do
      expect(source).to include("DeliverWorkflow.call_from_job")
      expect(source).not_to match(/Execution::Workflow\.call/)
    end

    it "does not configure ActiveJob retry_on for execution" do
      expect(code_without_comments).not_to match(/\bretry_on\b/)
    end
  end

  it "does not define replaced PORO Workflow constants" do
    expect(defined?(CommandTower::Messaging::Handoff::Workflow)).to be_nil
    expect(defined?(CommandTower::Messaging::Execution::Workflow)).to be_nil
  end
end
