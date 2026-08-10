# frozen_string_literal: true

require "rake"

RSpec.describe "CommandTower host install orchestrator" do
  let(:copy_engine_migrations!) do
    lambda do |destination|
      scope = CommandTower::Engine.engine_name
      # Engine.paths["db/migrate"].existent returns an Array of paths; Migration.copy wants a path string.
      source_path = CommandTower::Engine.paths["db/migrate"].first
      ActiveRecord::Migration.copy(
        destination,
        { scope => source_path },
        on_skip: proc {},
        on_copy: proc {}
      )
    end
  end

  before(:all) do
    Rails.application.load_tasks
  end

  it "exposes command_tower:install and command_tower:doctor rake tasks" do
    expect(Rake::Task.task_defined?("command_tower:install")).to be(true)
    expect(Rake::Task.task_defined?("command_tower:doctor")).to be(true)
    expect(Rake::Task.task_defined?("command_tower:install:migrations")).to be(true)
  end

  context "when copying engine migrations into a host migrate directory" do
    subject(:copy_sequence) do
      host_root = Dir.mktmpdir("ct-host-migrate")
      migrate_dir = File.join(host_root, "db", "migrate")
      FileUtils.mkdir_p(migrate_dir)

      copy_engine_migrations!.call(migrate_dir)
      first = Dir.children(migrate_dir).grep(/command_tower/).sort

      copy_engine_migrations!.call(migrate_dir)
      second = Dir.children(migrate_dir).grep(/command_tower/).sort

      future = CommandTower::Install::Baseline.migrate_dir.join(
        "20260805000006_create_command_tower_phase53_future_delta.rb"
      )
      begin
        File.write(future, <<~RUBY)
          class CreateCommandTowerPhase53FutureDelta < ActiveRecord::Migration[7.2]
            def change
              create_table :command_tower_phase53_future_delta_probe do |t|
                t.timestamps
              end
            end
          end
        RUBY

        copy_engine_migrations!.call(migrate_dir)
        after_delta = Dir.children(migrate_dir).grep(/command_tower/).sort

        {
          host_root:,
          first:,
          second:,
          after_delta:,
        }
      ensure
        FileUtils.rm_f(future)
        FileUtils.remove_entry(host_root)
      end
    end

    it "copies the expected baseline migrations" do
      expect(copy_sequence[:first].size).to eq(CommandTower::Install::Baseline::ENGINE_MIGRATION_BASENAMES.size)
      expect(copy_sequence[:first]).to all(end_with(".command_tower.rb"))
    end

    it "copies engine migrations idempotently" do
      expect(copy_sequence[:second]).to eq(copy_sequence[:first])
    end

    it "copies the additional delta migration" do
      expect(copy_sequence[:after_delta].size).to eq(copy_sequence[:first].size + 1)
      expect(copy_sequence[:after_delta].grep(/phase53_future_delta/)).not_to be_empty
    end
  end

  context "when running doctor on the dummy app" do
    let(:findings) { CommandTower::Install::Doctor.new.run }
    let(:failures) { findings.select { |f| f.severity == :fail } }

    it "runs doctor successfully for rails/engine checks on the dummy app" do
      expect(findings.map(&:code)).to include(:rails_version, :engine_migrations, :jwt_secret)
      expect(failures.map(&:code)).not_to include(:rails_version, :engine_migrations)
    end
  end
end
