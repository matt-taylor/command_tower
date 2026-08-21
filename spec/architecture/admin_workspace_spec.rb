# frozen_string_literal: true

RSpec.describe "CommandTower Admin Workspace architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:engine_source) { File.read(engine_root.join("lib/command_tower/engine.rb")) }
  let(:manifest_source) do
    File.read(engine_root.join("app/services/command_tower/services/admin/workspace/manifest.rb"))
  end
  let(:workspace_controller_source) do
    File.read(engine_root.join("app/controllers/command_tower/admin/workspace_controller.rb"))
  end
  let(:routes_source) { File.read(engine_root.join("config/routes.rb")) }
  let(:platform_tools) { CommandTower::Configuration::Registry::AdminWorkspace::Config::PLATFORM_TOOLS }
  let(:account_serializer_source) do
    File.read(engine_root.join("app/serializers/command_tower/serializers/me/account_serializer.rb"))
  end
  let(:manifest_workflow_source) do
    File.read(engine_root.join("app/workflows/command_tower/workflows/admin/workspace/manifest_workflow.rb"))
  end
  let(:default_yml) { YAML.load_file(engine_root.join("lib/command_tower/authorization/default.yml")) }

  it "ships one Admin Workspace registry" do
    expect(File.exist?(engine_root.join("lib/command_tower/configuration/registry/admin_workspace/config.rb"))).to eq(true)
    expect(engine_source).to include("registry.admin_workspace.finalize!")
    expect(engine_source).to include("admin_workspace.validate_required_entities!")
  end

  it "does not introduce a generic tool dispatcher or god AdminController" do
    expect(routes_source).not_to include("admin/tools")
    expect(engine_source).not_to include("CommandTower::Admin.register")
    expect(
      Dir.glob(File.join(engine_root, "app/controllers/**/*_controller.rb")).map { |path| File.basename(path) }
    ).not_to include("admin_controller.rb")
  end

  it "keeps admin discovery off /me" do
    expect(account_serializer_source).not_to include("admin_workspace")
    expect(account_serializer_source).not_to include("sortOrder")
  end

  it "declares ManifestWorkflow retry_strategy :none in its own file" do
    expect(manifest_workflow_source).to include("retry_strategy :none")
    expect(File.exist?(engine_root.join("app/workflows/command_tower/workflows/admin/workspace/events.rb"))).to eq(false)
  end

  it "keeps the workspace controller as manifest transport only" do
    expect(workspace_controller_source).to include("ManifestWorkflow.call")
    expect(workspace_controller_source).not_to include("CreateAnnouncement")
    expect(workspace_controller_source).not_to include("ListForAdmin")
  end

  it "filters the manifest from the RBAC grant graph rather than role-name equality" do
    expect(manifest_source).to include("allow_everything")
    expect(manifest_source).to include("required_entity")
    expect(manifest_source).not_to include('== "admin"')
    expect(manifest_source).not_to include("role == :admin")
  end

  it "does not seed Pick'em vocabulary into CommandTower-owned tools" do
    expect(platform_tools.inspect).not_to include("pickem")
    expect(platform_tools.inspect).not_to include("wager")
    expect(platform_tools.inspect).not_to include("league")
    expect(platform_tools.keys).to contain_exactly(:users, :audit, :messaging)
  end

  it "does not ship an accumulating CommandTower operational admin role" do
    expect(default_yml.fetch("groups").keys.map(&:to_s)).to eq(%w[owner])
    expect(default_yml.dig("groups", "owner", "entities")).to eq(true)
  end
end
