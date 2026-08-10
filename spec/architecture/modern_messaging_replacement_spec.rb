# frozen_string_literal: true

RSpec.describe "Modern messaging replacement architecture" do
  let(:source_for) do
    lambda do |path|
      File.read(Rails.root.join("../../", path).expand_path)
    rescue Errno::ENOENT
      File.read(CommandTower::Engine.root.join(path))
    end
  end

  context "Register ApplicationService" do
    let(:source) { File.read(CommandTower::Engine.root.join("app/services/command_tower/services/auth/register.rb")) }

    it "no longer references NewUserBlaster" do
      expect(source).not_to include("NewUserBlaster")
    end
  end

  context "RegisterWorkflow" do
    let(:source) { File.read(CommandTower::Engine.root.join("app/workflows/command_tower/workflows/auth/register_workflow.rb")) }

    it "emits welcome via Communications::Produce synchronously" do
      expect(source).to include("Communications::Produce")
      expect(source).to include("welcome_content")
      expect(source).not_to include("WelcomeNotificationJob")
      expect(source).not_to include("NewUserBlaster")
      expect(source).not_to include("perform_later")
    end
  end

  context "ProduceMany" do
    let(:source) do
      File.read(
        CommandTower::Engine.root.join("app/services/command_tower/services/messaging/communications/produce_many.rb")
      )
    end

    it "calls single-user Produce and does not call Accept directly" do
      expect(source).to include("Communications::Produce.call")
      expect(source).not_to include("Messaging.accept")
      expect(source).not_to include("MessageBlast")
      expect(source).not_to include("User.all")
    end
  end

  it "removes legacy InboxService and Message models" do
    expect(defined?(CommandTower::InboxService)).to be_nil
    expect(defined?(Message)).to be_nil
    expect(defined?(MessageBlast)).to be_nil
  end

  context "routing" do
    let(:engine) { File.read(CommandTower::Engine.root.join("config/routes.rb")) }
    let(:legacy_path) { CommandTower::Engine.root.join("config/legacy_application_routes.rb") }

    it "removes legacy SchemaHelper host routes file and keeps modern Me Inbox and announcements" do
      expect(legacy_path).not_to exist

      expect(engine).to include("namespace :me do")
      expect(engine).to include("resources :inbox")
      expect(engine).to include("namespace :admin do")
      expect(engine).to include("namespace :messaging do")
      expect(engine).to include('post "announcements"')
      expect(engine).not_to include("legacy_application_routes")
    end
  end
end
