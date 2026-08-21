# frozen_string_literal: true

RSpec.describe "CommandTower admin impersonation prohibition architecture" do
  let(:engine_root) { CommandTower::Engine.root }

  it "requires Admin controllers to inherit the impersonation prohibition boundary" do
    paths = Dir[engine_root.join("app/controllers/command_tower/admin/**/*_controller.rb").to_s]
    offenders = paths.filter_map do |path|
      next if File.basename(path) == "application_controller.rb"

      source = File.read(path)
      next if source.include?("CommandTower::Admin::ApplicationController")

      Pathname.new(path).relative_path_from(engine_root).to_s
    end

    expect(offenders).to eq([])
  end

  it "skips the prohibition only for workspace show" do
    source = File.read(engine_root.join("app/controllers/command_tower/admin/workspace_controller.rb"))
    expect(source).to include("skip_before_action :reject_admin_operations_during_impersonation!")
    expect(source).to include("only: :show")
  end

  it "registers admin_unavailable_during_impersonation" do
    error = CommandTower::Errors::Auth::AdminUnavailableDuringImpersonationError.new
    expect(error.code).to eq("admin_unavailable_during_impersonation")
  end
end
