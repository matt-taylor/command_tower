# frozen_string_literal: true

# Blank-host proof independent of DFM / dummy rails_app.
# Creates a throwaway Rails API app, installs CommandTower via the productized
# rake entry point, migrates, and asserts boot + schema.
#
# Skip with SKIP_BLANK_HOST=1.
RSpec.describe "Blank host CommandTower installation", :blank_host do
  before do
    skip "Skipped via SKIP_BLANK_HOST=1" if ENV["SKIP_BLANK_HOST"] == "1"
  end

  it "installs, migrates, boots, and picks up a future engine migration" do
    FileUtils.rm_rf(blank_root)
    FileUtils.mkdir_p(blank_root.dirname)
    drop_blank_database!

    ok = Dir.chdir("/tmp") do
      system(
        { "BUNDLE_GEMFILE" => engine_root.join("Gemfile").to_s },
        "bundle", "exec", "rails", "new", blank_root.to_s,
        "--api",
        "--database=mysql",
        "--skip-javascript",
        "--skip-hotwire",
        "--skip-test",
        "--skip-system-test",
        "--skip-solid",
        "--skip-bundle",
        "--force"
      )
    end
    raise "rails new blank_host_install failed" unless ok

    gemfile = blank_root.join("Gemfile")
    gemfile_contents = File.read(gemfile)
    gemfile_contents.sub!(/^gem ["']rails["'].*$/, 'gem "rails", "~> 8"')
    unless gemfile_contents.include?("command_tower")
      gemfile_contents << <<~RUBY

        gem "command_tower", path: #{engine_root.to_s.inspect}
      RUBY
    end
    File.write(gemfile, gemfile_contents)
    write_database_yml!

    sh!("bundle", "install")

    install_out = sh!("bin/rails", "command_tower:install")
    expect(install_out).to include("CommandTower install")

    installed = Dir.children(blank_root.join("db/migrate")).grep(/command_tower/).sort
    expect(installed.size).to eq(5)
    expect(installed).to all(end_with(".command_tower.rb"))

    sh!("bin/rails", "command_tower:install", env: host_env.merge("SKIP_CONFIGURE" => "1"))
    reinstalled = Dir.children(blank_root.join("db/migrate")).grep(/command_tower/).sort
    expect(reinstalled).to eq(installed)

    sh!("bin/rails", "db:create", "db:migrate")

    probe = blank_root.join("tmp_blank_host_probe.rb")
    File.write(probe, <<~'RUBY')
      raise "missing CommandTower" unless defined?(CommandTower)
      tables = ActiveRecord::Base.connection.data_sources
      required = %w[users user_secrets messaging_communications]
      missing = required - tables
      raise "missing tables: #{missing.inspect}" if missing.any?
      puts "BLANK_HOST_OK"
    RUBY

    runner = sh!("bin/rails", "runner", probe.to_s)
    expect(runner).to include("BLANK_HOST_OK")

    doctor = sh!("bin/rails", "command_tower:doctor")
    expect(doctor).to match(/Doctor passed/)

    # --- Shared factory distribution proof (Phase 5.5) ---
    gemfile_contents = File.read(gemfile)
    unless gemfile_contents.include?("factory_bot")
      gemfile_contents << <<~RUBY

        gem "factory_bot"
      RUBY
      File.write(gemfile, gemfile_contents)
      sh!("bundle", "install")
    end

    factory_probe = blank_root.join("tmp_blank_host_factory_probe.rb")
    File.write(factory_probe, <<~'RUBY')
      require "factory_bot"
      require "command_tower/testing"

      CommandTower::Testing.ensure_endpoint_secret!
      CommandTower::Testing.install!
      raise "expected factories_loaded!" unless CommandTower::Testing.factories_loaded?

      include FactoryBot::Syntax::Methods

      user = create(:user)
      create(:user_secret, user:)
      create(:messaging_communication, user:)
      create(:messaging_destination_plan)
      create(:messaging_inbox_item)
      create(:messaging_channel_delivery)
      create(:messaging_delivery_attempt)
      create(:messaging_notification_preference, user:)
      create(:messaging_endpoint, user:)
      create(:messaging_endpoint, :verified, user: create(:user))
      create(:messaging_endpoint_pushover_credential)
      build(:authorization_role)
      build(:authorization_entity)

      FactoryBot.modify do
        factory :user do
          trait :blank_host_marker do
            first_name { "BlankHost" }
          end
        end
      end

      marked = create(:user, :blank_host_marker)
      raise "modify trait failed" unless marked.first_name == "BlankHost"

      CommandTower::Testing.install!
      raise "install! not idempotent" unless CommandTower::Testing.factories_loaded?

      begin
        FactoryBot.define do
          factory :user, class: "User" do
            sequence(:email) { |n| "dup#{n}@example.com" }
          end
        end
        raise "expected duplicate :user definition to raise"
      rescue FactoryBot::DuplicateDefinitionError
        # expected — CT :user remains registered; host must use modify
      end

      puts "BLANK_HOST_FACTORIES_OK"
    RUBY

    factory_runner = sh!("bin/rails", "runner", factory_probe.to_s)
    expect(factory_runner).to include("BLANK_HOST_FACTORIES_OK")

    # Rails 8 rejects far-future migration timestamps; stay just after the baseline head.
    future = engine_root.join("db/migrate/20260805000006_create_command_tower_blank_host_delta.rb")
    begin
      File.write(future, <<~RUBY)
        class CreateCommandTowerBlankHostDelta < ActiveRecord::Migration[7.2]
          def change
            create_table :command_tower_blank_host_delta_probe do |t|
              t.timestamps
            end
          end
        end
      RUBY

      before_count = Dir.children(blank_root.join("db/migrate")).grep(/command_tower/).size
      sh!("bin/rails", "command_tower:install", env: host_env.merge("SKIP_CONFIGURE" => "1"))
      after = Dir.children(blank_root.join("db/migrate")).grep(/command_tower/).sort
      expect(after.size).to eq(before_count + 1)
      expect(after.grep(/blank_host_delta/)).not_to be_empty
    ensure
      FileUtils.rm_f(future)
      FileUtils.rm_f(probe)
      FileUtils.rm_f(factory_probe)
    end
  ensure
    drop_blank_database!
    FileUtils.rm_rf(blank_root) if blank_root&.exist?
  end
end
