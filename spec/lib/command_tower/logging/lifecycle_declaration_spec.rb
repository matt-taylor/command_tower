# frozen_string_literal: true

RSpec.describe CommandTower::Logging::LifecycleDeclaration do
  let(:workflow_class) do
    Class.new(CommandTower::Workflows::ApplicationWorkflow) do
      retry_strategy :none
    end
  end
  let(:service_class) { Class.new(CommandTower::Services::ApplicationService) }

  it "logs workflow completions by default" do
    expect(CommandTower::Workflows::ApplicationWorkflow.lifecycle_loggable?).to eq(true)
    expect(workflow_class.lifecycle_loggable?).to eq(true)
  end

  it "keeps services quiet by default" do
    expect(CommandTower::ServiceBase.lifecycle_loggable?).to eq(false)
    expect(service_class.lifecycle_loggable?).to eq(false)
  end

  context "when a workflow disables inherited lifecycle logging" do
    let(:quiet) do
      Class.new(workflow_class) do
        disable_lifecycle_logging!
      end
    end

    it { expect(quiet.lifecycle_loggable?).to eq(false) }
  end

  context "when a service opts in" do
    let(:noisy) do
      Class.new(service_class) do
        log_lifecycle!
      end
    end

    it { expect(noisy.lifecycle_loggable?).to eq(true) }
  end
end
