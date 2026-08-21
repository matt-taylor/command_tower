# frozen_string_literal: true

RSpec.describe CommandTower::Execution::JobBoundary do
  after { CommandTower::Current.reset }

  let(:probe) { { execution_uuid: nil, source: nil, service_uuid: nil } }

  let(:service_class) do
    Class.new(CommandTower::Services::ApplicationService) do
      define_method(:call) do
        context.uuid = execution_context.execution_uuid
      end
    end
  end

  let(:job_class) do
    captured = probe
    nested = service_class
    Class.new(CommandTower::ApplicationJob) do
      define_method(:perform) do |fail_now = false|
        captured[:execution_uuid] = CommandTower::Current.execution_uuid
        captured[:source] = CommandTower::Current.source
        captured[:service_uuid] = nested.call.data[:uuid]
        raise StandardError, "job boom" if fail_now
      end
    end
  end

  before { stub_const("CommandTower::ExecutionProbeJob", job_class) }

  context "when perform succeeds" do
    before { CommandTower::ExecutionProbeJob.perform_now }

    it "establishes a job execution context shared with nested services" do
      expect(probe[:source]).to eq(:job)
      expect(probe[:execution_uuid]).to be_present
      expect(probe[:service_uuid]).to eq(probe[:execution_uuid])
    end

    it { expect(CommandTower::Current.execution_uuid).to be_nil }
  end

  context "when perform raises" do
    subject(:after_raise) do
      CommandTower::ExecutionProbeJob.perform_now(true)
    rescue StandardError
      CommandTower::Current.execution_uuid
    end

    it { expect(after_raise).to be_nil }
  end
end
