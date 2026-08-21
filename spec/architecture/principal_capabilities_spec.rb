# frozen_string_literal: true

RSpec.describe "CommandTower principal capabilities architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:engine_source) { File.read(engine_root.join("lib/command_tower/engine.rb")) }
  let(:project_source) do
    File.read(
      engine_root.join("app/services/command_tower/services/auth/principal_capabilities/project.rb")
    )
  end
  let(:controller_source) do
    File.read(engine_root.join("app/controllers/command_tower/auth/principal_capabilities_controller.rb"))
  end
  let(:workflow_source) do
    File.read(
      engine_root.join("app/workflows/command_tower/workflows/auth/principal_capabilities/show_workflow.rb")
    )
  end
  let(:account_serializer_source) do
    File.read(engine_root.join("app/serializers/command_tower/serializers/me/account_serializer.rb"))
  end
  let(:session_serializer_source) do
    File.read(engine_root.join("app/serializers/command_tower/serializers/auth/user_serializer.rb"))
  end
  let(:identity_policy_source) do
    File.read(
      engine_root.join("app/serializers/command_tower/serializers/auth/identity_policy_serializer.rb")
    )
  end
  let(:manifest_source) do
    File.read(engine_root.join("app/services/command_tower/services/admin/workspace/manifest.rb"))
  end
  let(:platform_capabilities) do
    CommandTower::Configuration::Registry::PrincipalCapabilities::Config::PLATFORM_CAPABILITIES
  end
  let(:default_yml) { YAML.load_file(engine_root.join("lib/command_tower/authorization/default.yml")) }

  it "ships one principal capabilities registry with finalize and post-RBAC validation" do
    expect(
      File.exist?(engine_root.join("lib/command_tower/configuration/registry/principal_capabilities/config.rb"))
    ).to eq(true)
    expect(engine_source).to include("registry.principal_capabilities.finalize!")
    expect(engine_source).to include("principal_capabilities.validate_required_entities!")
  end

  it "keeps projection off /me, session user payload, and identity-policy" do
    expect(account_serializer_source).not_to include("principalCapabilities")
    expect(account_serializer_source).not_to include("principal_capabilities")
    expect(session_serializer_source).not_to include("principalCapabilities")
    expect(identity_policy_source).not_to include("principalCapabilities")
  end

  it "does not put Admin tool manifests into principal projection" do
    expect(project_source).not_to include("admin_workspace.definitions")
    expect(project_source).not_to include("sort_order")
    expect(project_source).not_to include("label")
    expect(manifest_source).not_to include("principal_capabilities")
  end

  it "projects from entity grants and allow_everything without role-name checks" do
    expect(project_source).to include("allow_everything")
    expect(project_source).to include("required_entity")
    expect(project_source).not_to include('== "admin"')
    expect(project_source).not_to include('== "owner"')
    expect(project_source).not_to include("role == :admin")
  end

  it "keeps the controller as ShowWorkflow transport only" do
    expect(controller_source).to include("ShowWorkflow.call")
    expect(controller_source).not_to include("PrincipalCapabilities::Project.call")
    expect(workflow_source).to include("retry_strategy :none")
  end

  it "seeds the curated CT Admin and Me projectable catalog" do
    expect(platform_capabilities).to contain_exactly(
      :admin_workspace,
      :admin_audit_events,
      :admin_messaging_announcements,
      :admin_users,
      :admin_users_update,
      :admin_rbac_assignments,
      :admin_impersonation,
      :me_audit_events
    )
    expect(platform_capabilities.inspect).not_to include("session")
    expect(platform_capabilities.inspect).not_to include("me_inbox")
    expect(platform_capabilities.inspect).not_to include("pickem")
    expect(platform_capabilities).not_to include(:impersonation)
  end

  it "does not ship an accumulating CommandTower operational admin role" do
    expect(default_yml.fetch("groups").keys.map(&:to_s)).to eq(%w[owner])
  end

  it "does not auto-register every RBAC entity as projectable" do
    expect(default_yml.fetch("entities").map { |entity| entity.fetch("name") }).to include(
      "session", "me", "principal_capabilities"
    )
    expect(platform_capabilities.map(&:to_s)).not_to include("session", "me", "principal_capabilities")
  end
end
