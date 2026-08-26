# frozen_string_literal: true

RSpec.describe "CommandTower audit architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:persistence_source) do
    File.read(engine_root.join("lib/command_tower/audit/persistence/subscriber.rb"))
  end
  let(:engine_source) { File.read(engine_root.join("lib/command_tower/engine.rb")) }
  let(:logging_source) { File.read(engine_root.join("lib/command_tower/logging/subscriber.rb")) }
  let(:migration_source) do
    File.read(engine_root.join("db/migrate/20260816000001_create_command_tower_audit_events.rb"))
  end
  let(:controller_audit_offenders) do
    Dir[engine_root.join("app/{models,controllers,jobs,mailers}/**/*.rb").to_s].filter_map do |path|
      next unless File.read(path).match?(/\baudit\s*\(/)

      Pathname.new(path).relative_path_from(engine_root).to_s
    end
  end
  let(:password_change_keys) do
    CommandTower::Configuration::Registry::Audit::Config::PLATFORM_EVENTS.filter_map do |name, attrs|
      forbidden = Array(attrs[:allowed_changes]).map(&:to_s).grep(/password/)
      next if forbidden.empty?

      "#{name}: #{forbidden.join(",")}"
    end
  end
  let(:mandatory_event_names) do
    %i[
      user_registered
      role_assigned
      role_revoked
      password_changed
      account_deleted
      email_verified
      phone_updated
      phone_cleared
      phone_verified
      admin_user_name_changed
      admin_user_username_changed
      admin_user_email_changed
      admin_user_email_validation_changed
      announcement_produced
      impersonation_started
      impersonation_ended
    ]
  end
  let(:configurable_event_names) { %i[session_created session_cleared login_failed] }
  let(:me_audit_events_controller_source) do
    File.read(engine_root.join("app/controllers/command_tower/me/audit_events_controller.rb"))
  end
  let(:admin_audit_events_controller_source) do
    File.read(engine_root.join("app/controllers/command_tower/admin/audit/events_controller.rb"))
  end
  let(:audit_events_service_source) do
    File.read(engine_root.join("app/services/command_tower/services/audit/events.rb"))
  end
  let(:audit_events_workflow_source) do
    Dir[engine_root.join("app/workflows/command_tower/workflows/audit/events/**/*.rb").to_s].map { |path| File.read(path) }.join("\n")
  end

  it "ships one ledger model" do
    expect(Dir[engine_root.join("app/models/command_tower/audit/event.rb").to_s]).to eq(
      [engine_root.join("app/models/command_tower/audit/event.rb").to_s]
    )
  end

  it "ships audit migrations" do
    expect(Dir[engine_root.join("db/migrate/**/*audit*").to_s].map { |path| File.basename(path) }).to eq(
      [
        "20260816000001_create_command_tower_audit_events.rb",
        "20260817000001_add_scope_columns_to_command_tower_audit_events.rb"
      ]
    )
  end

  it "ships one persistence subscriber attached at boot" do
    expect(File.exist?(engine_root.join("lib/command_tower/audit/persistence/subscriber.rb"))).to eq(true)
    expect(engine_source).to include("Audit::Persistence::Subscriber.attach!")
  end

  it "does not introduce a second audit bus" do
    expect(
      Dir[engine_root.join("{app,lib}/**/*.rb").to_s].none? { |path| File.read(path).include?("AuditEventBus") }
    ).to eq(true)
  end

  it "persists synchronously without after_commit, jobs, swallowed errors, or its own transaction" do
    expect(persistence_source).to include("Event.create!")
    expect(persistence_source).not_to include("after_commit")
    expect(persistence_source).not_to include("perform_async")
    expect(persistence_source).not_to include("rescue")
    expect(persistence_source).not_to include("requires_new")
    expect(persistence_source).not_to include(".transaction")
  end

  it "does not persist audit through the logging subscriber" do
    expect(logging_source).not_to include("command_tower.audit")
  end

  it "does not add foreign keys or a visibility column" do
    expect(migration_source).not_to match(/foreign_key|references :|t\.references/)
    expect(migration_source).not_to include("visibility")
  end

  it "does not emit audit from models, controllers, jobs, or mailers" do
    expect(controller_audit_offenders).to eq([])
  end

  it "does not allow password keys on CommandTower-owned allowed_changes" do
    expect(password_change_keys).to eq([])
  end

  it "marks core CommandTower facts as not enablement-configurable" do
    expect(mandatory_event_names.map { |name| CommandTower.config.registry.audit.fetch(name).enablement_configurable? }).to eq(
      Array.new(mandatory_event_names.size, false)
    )
  end

  it "marks session and login_failed facts as enablement-configurable" do
    expect(configurable_event_names.map { |name| CommandTower.config.registry.audit.fetch(name).enablement_configurable? }).to eq(
      [true, true, true]
    )
  end

  it "does not add a second audit table" do
    expect(Dir[engine_root.join("app/models/command_tower/audit/**/*.rb").to_s]).to eq(
      [engine_root.join("app/models/command_tower/audit/event.rb").to_s]
    )
  end

  it "keeps Me audit reads free of target-user params" do
    expect(me_audit_events_controller_source).not_to include("affectedUserId")
    expect(me_audit_events_controller_source).not_to include("affected_user_id")
    expect(me_audit_events_controller_source).not_to include("params[:user_id]")
  end

  it "enforces user scope in List with affected_user_id and snapshot user_history" do
    expect(audit_events_service_source).to include("viewer_scope")
    expect(audit_events_service_source).to include("affected_user_id:, user_history: true")
    expect(audit_events_service_source).not_to include(".all")
  end

  it "projects through Project before serialize and does not query from workflows" do
    expect(audit_events_workflow_source).to include("Services::Audit::Events::Project.call")
    expect(audit_events_workflow_source).to include("EventSerializer.serialize")
    expect(audit_events_workflow_source).not_to include("CommandTower::Audit::Event")
    expect(audit_events_workflow_source).not_to include(".where")
    expect(audit_events_workflow_source).not_to include(".order")
  end

  it "does not serialize Audit::Event from controllers" do
    expect(me_audit_events_controller_source).not_to include("CommandTower::Audit::Event")
    expect(admin_audit_events_controller_source).not_to include("CommandTower::Audit::Event")
    expect(me_audit_events_controller_source).not_to include("Serializer.serialize")
    expect(admin_audit_events_controller_source).not_to include("Serializer.serialize")
  end
end
