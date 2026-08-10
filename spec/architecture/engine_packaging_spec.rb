# frozen_string_literal: true

RSpec.describe "CommandTower engine packaging" do
  let(:gemspec_path) { CommandTower::Engine.root.join("command_tower.gemspec") }
  let(:spec) { Gem::Specification.load(gemspec_path.to_s) }
  let(:files) { spec.files }
  let(:rails_dep) { spec.dependencies.find { |d| d.name == "rails" } }

  it "packages migrations, generators, rake tasks, initializing docs, testing API, and factories" do
    expect(files).to include(a_string_matching(%r{\Adb/migrate/20260805000001_create_command_tower_users\.rb\z}))
    expect(files).to include(a_string_matching(%r{\Alib/generators/command_tower/configure/configure_generator\.rb\z}))
    expect(files).to include(a_string_matching(%r{\Alib/tasks/install\.rake\z}))
    expect(files).to include("docs/initializing.md")
    expect(files).to include(a_string_matching(%r{\Alib/command_tower/testing\.rb\z}))
    expect(files).to include(a_string_matching(%r{\Aspec/factories/user\.rb\z}))
    expect(files).to include(a_string_matching(%r{\Aspec/factories/messaging\.rb\z}))
  end

  it "declares a Rails dependency covering 7.x and 8.x" do
    expect(rails_dep).not_to be_nil
    expect(rails_dep.requirement).to satisfy(">= 7.0") { |req| req.satisfied_by?(Gem::Version.new("7.0.0")) }
    expect(rails_dep.requirement).to satisfy("< 9.0") { |req| req.satisfied_by?(Gem::Version.new("8.9.9")) }
    expect(rails_dep.requirement).not_to satisfy("rejects 9") { |req| req.satisfied_by?(Gem::Version.new("9.0.0")) }
  end
end
