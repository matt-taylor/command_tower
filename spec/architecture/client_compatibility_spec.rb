# frozen_string_literal: true

RSpec.describe "CommandTower client compatibility architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:engine_source) { File.read(engine_root.join("lib/command_tower/engine.rb")) }
  let(:evaluate_source) do
    File.read(
      engine_root.join("app/services/command_tower/services/client_compatibility/evaluate.rb")
    )
  end
  let(:evaluate_workflow_source) do
    File.read(
      engine_root.join("app/workflows/command_tower/workflows/client_compatibility/evaluate_workflow.rb")
    )
  end
  let(:boundary_source) do
    File.read(
      engine_root.join("app/controllers/concerns/command_tower/execution/client_compatibility_boundary.rb")
    )
  end
  let(:session_error_status_source) do
    File.read(engine_root.join("app/workflows/command_tower/workflows/auth/session_error_status.rb"))
  end

  it "ships one client_compatibility registry with finalize and post-RBAC validation" do
    expect(
      File.exist?(engine_root.join("lib/command_tower/configuration/registry/client_compatibility/config.rb"))
    ).to eq(true)
    expect(engine_source).to include("registry.client_compatibility.finalize!")
    expect(engine_source).to include("registry.client_compatibility.validate!")
    expect(engine_source).to include("registry.client_compatibility.apply_env_overlay!")
  end

  it "ships an empty CommandTower-owned catalog (no placeholder seeds)" do
    expect(CommandTower::Configuration::Registry::ClientCompatibility::Config::PLATFORM_CONTRACTS).to eq([])
    expect(CommandTower::Configuration::Registry::ClientCompatibility::Config::PLATFORM_ENTITY_REQUIREMENTS).to eq({})
  end

  it "keeps Evaluate a pure decision service with no Current writes and no Authorize::Validate" do
    expect(evaluate_source).not_to include("CommandTower::Current.")
    expect(evaluate_source).not_to include("Authorize::Validate")
    expect(evaluate_source).to include("Entity.entities")
    expect(evaluate_source).to include("matches?(")
  end

  it "confines the Current stash and 426 mapping to the workflow, not the service" do
    expect(evaluate_workflow_source).to include("CommandTower::Current.client_compatibility_recommendation")
    expect(evaluate_workflow_source).to include(":upgrade_required")
    expect(evaluate_workflow_source).to include("retry_strategy :none")
  end

  it "does not write lifecycle observation directly to Rails.logger from the workflow" do
    expect(evaluate_workflow_source).not_to match(/Rails\.logger\./)
    expect(evaluate_workflow_source).to include("publish_event(")
  end

  it "keeps the boundary transport-only, running exactly one workflow" do
    expect(boundary_source).to include("EvaluateWorkflow.call")
    expect(boundary_source).to include("before_action :evaluate_client_compatibility!")
  end

  it "never maps ClientUpdateRequiredError through the closed SessionErrorStatus table" do
    expect(session_error_status_source).not_to include("ClientUpdateRequiredError")

    expect(
      CommandTower::Workflows::Auth::SessionErrorStatus.http_status_for(
        CommandTower::Errors::ClientUpdateRequiredError.new
      )
    ).to eq(:internal_server_error)
  end

  it "merges recommended-update meta only in Login and Session::Show workflows" do
    login_source = File.read(
      engine_root.join("app/workflows/command_tower/workflows/auth/plain_text/login_workflow.rb")
    )
    session_show_source = File.read(
      engine_root.join("app/workflows/command_tower/workflows/auth/session/show_workflow.rb")
    )

    expect(login_source).to include("client_compatibility_meta")
    expect(session_show_source).to include("client_compatibility_meta")

    other_workflow_sources = Dir[engine_root.join("app/workflows/**/*.rb")].reject do |path|
      path.end_with?("auth/plain_text/login_workflow.rb") ||
        path.end_with?("auth/session/show_workflow.rb") ||
        path.include?("client_compatibility")
    end

    other_workflow_sources.each do |path|
      expect(File.read(path)).not_to include("client_compatibility_meta"), "unexpected clientCompatibility meta usage in #{path}"
    end
  end
end
