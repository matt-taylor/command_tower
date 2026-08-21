# frozen_string_literal: true

RSpec.describe "CommandTower admin resource scoping architecture" do
  let(:engine_root) { CommandTower::Engine.root }

  it "does not introduce League or tenant semantics in production CommandTower code" do
    forbidden = /\b(League|Season|Tenant|Organization)\b/
    paths = Dir[engine_root.join("{app,lib}/**/*.rb").to_s]
    offenders = paths.filter_map do |path|
      next if path.include?("/spec/")

      content = File.read(path)
      next unless content.match?(forbidden)

      Pathname.new(path).relative_path_from(engine_root).to_s
    end

    expect(offenders).to eq([])
  end

  it "ships admin_scope configuration" do
    expect(File.exist?(engine_root.join("lib/command_tower/configuration/admin_scope/config.rb"))).to eq(true)
    expect(File.exist?(engine_root.join("lib/command_tower/admin_scope/resolve.rb"))).to eq(true)
  end

  it "narrows Users before pagination in the list service" do
    source = File.read(engine_root.join("app/services/command_tower/services/admin/users.rb"))
    narrowing_index = source.index("ApplyUsersNarrowing.call")
    search_index = source.index("apply_search")
    count_index = source.index("total_count: relation.count")

    expect(narrowing_index).to be < search_index
    expect(search_index).to be < count_index
  end

  it "uses scoped relation lookup for Users show" do
    source = File.read(engine_root.join("app/services/command_tower/services/admin/users.rb"))
    expect(source).to include("NotFoundError")
    expect(source).not_to include("User.find(")
  end

  it "persists explicit audit scope_class" do
    migration = Dir[engine_root.join("db/migrate/*scope*audit*").to_s].map { |path| File.read(path) }.join("\n")
    expect(migration).to include("scope_class")
    expect(migration).to include("legacy")
  end

  it "excludes legacy scope from scoped audit composition" do
    source = File.read(engine_root.join("lib/command_tower/admin_scope/apply_audit_scoping.rb"))
    expect(source).to include("SCOPE_CLASSES[:legacy]")
  end

  it "resolves impersonation start targets through scoped Admin Users Show" do
    source = File.read(engine_root.join("app/workflows/command_tower/workflows/impersonation/start_workflow.rb"))
    expect(source).to include("ScopeResolution.resolve")
    expect(source).to include("CommandTower::Services::Admin::Users::Show.call")
    expect(source).not_to match(/User\.find(_by)?[!(]/)
  end
end
