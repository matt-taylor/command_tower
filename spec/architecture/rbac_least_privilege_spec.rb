# frozen_string_literal: true

RSpec.describe "CommandTower RBAC least-privilege architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:default_yml) { YAML.load_file(engine_root.join("lib/command_tower/authorization/default.yml")) }
  let(:manifest_source) do
    File.read(engine_root.join("app/services/command_tower/services/admin/workspace/manifest.rb"))
  end
  let(:entity_names) { Array(default_yml["entities"]).map { |row| row.fetch("name") } }
  let(:non_owner_admin_grants) do
    Array(default_yml.dig("groups")&.values).flat_map do |group|
      next [] if group["entities"] == true

      Array(group["entities"]).map(&:to_s).grep(/\Aadmin_/)
    end
  end

  it "ships owner as the only CommandTower role group" do
    expect(default_yml.fetch("groups").keys.map(&:to_s)).to eq(%w[owner])
  end

  it "keeps Admin capability entities CommandTower-owned without granting them from CT roles" do
    expect(entity_names).to include(
      "admin_workspace",
      "admin_audit_events",
      "admin_messaging_announcements",
      "admin_users",
      "admin_users_update",
      "admin_rbac_assignments",
      "admin_impersonation"
    )
    expect(non_owner_admin_grants).to eq([])
  end

  it "filters Admin Workspace tools by entity grants, not role-name equality" do
    expect(manifest_source).to include("allow_everything")
    expect(manifest_source).to include("required_entity")
    expect(manifest_source).not_to include('== "admin"')
    expect(manifest_source).not_to include("role == :admin")
    expect(manifest_source).not_to include('roles.include?("admin")')
  end

  it "authorizes role assignment by effective grants, not role-name possession" do
    policy_source = File.read(
      engine_root.join("app/services/command_tower/services/admin/users.rb")
    )
    expect(policy_source).to include("EffectiveEntityGrants")
    expect(policy_source).not_to include("actor.roles.include?")
  end
end
