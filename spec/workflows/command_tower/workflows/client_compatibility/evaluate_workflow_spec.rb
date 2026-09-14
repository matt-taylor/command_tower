# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::ClientCompatibility::EvaluateWorkflow do
  let(:request) do
    ActionDispatch::TestRequest.create.tap do |req|
      req.headers["X-App-Version"] = app_version
      req.headers["X-Client-Platform"] = "web"
    end
  end

  subject(:result) do
    described_class.call(
      request: request,
      controller_class: CommandTower::Auth::SessionController,
      action_name: "show"
    )
  end

  context "in observe mode (dummy default)" do
    let(:app_version) { "0.1.0" }

    it "continues (success) even when identity is below the configured minimum" do
      expect(result).to be_success
    end
  end

  context "in enforce mode" do
    before { CommandTower.config.registry.client_compatibility.mode = :enforce }

    context "when the version is below the configured minimum" do
      let(:app_version) { "0.1.0" }

      it "fails with client_update_required and http_status upgrade_required" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:upgrade_required)
        expect(result.errors.first.code).to eq("client_update_required")
      end
    end

    context "when the version satisfies the configured minimum" do
      let(:app_version) { "1.0.0" }

      it "succeeds" do
        expect(result).to be_success
      end
    end
  end

  context "when the decision is recommended" do
    before do
      CommandTower.config.registry.client_compatibility.reset_host_definitions!
      CommandTower.config.registry.client_compatibility.platform(:web) do |p|
        p.minimum = "1.0.0"
        p.recommended = "1.5.0"
      end
    end

    let(:app_version) { "1.2.0" }

    it "stashes the recommendation projection onto Current" do
      result
      expect(CommandTower::Current.client_compatibility_recommendation).to include(recommendedVersion: "1.5.0")
    end
  end

  context "when the decision is incompatible in observe mode" do
    let(:app_version) { "0.1.0" }

    it "does not stash a recommendation projection onto Current" do
      result
      expect(CommandTower::Current.client_compatibility_recommendation).to be_nil
    end
  end
end
