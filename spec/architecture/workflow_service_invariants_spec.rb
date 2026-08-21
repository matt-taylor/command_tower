# frozen_string_literal: true

RSpec.describe "CommandTower workflow and service architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:workflow_and_service_files) do
    Dir[engine_root.join("app/{workflows,services}/**/*.rb").to_s]
  end

  let(:logger_allowlist) do
    %w[
      app/services/command_tower/jwt/decode.rb
      app/services/command_tower/jwt/authenticate_user.rb
      app/services/command_tower/messaging/pushover/adapters/log_adapter.rb
      app/services/command_tower/messaging/execution/adapters/sms/log_adapter.rb
      app/services/command_tower/identity/phone_verification/sms_transport/adapters/log_adapter.rb
    ]
  end

  let(:relative) do
    lambda do |path|
      Pathname.new(path).relative_path_from(engine_root).to_s
    end
  end

  let(:boundary_offenders) do
    workflow_and_service_files.filter_map do |path|
      source = File.read(path)
      next unless source.match?(/with_execution|Current\.set|Current\.reset_all|Current\.reset\b/)

      relative.call(path)
    end
  end

  let(:instrument_offenders) do
    workflow_and_service_files.filter_map do |path|
      next unless File.read(path).include?("ActiveSupport::Notifications.instrument")

      relative.call(path)
    end
  end

  let(:lifecycle_offenders) do
    workflow_and_service_files.filter_map do |path|
      rel = relative.call(path)
      next if rel.end_with?("application_workflow.rb")
      next if rel.end_with?("service_base.rb")

      source = File.read(path)
      next unless source.match?(/command_tower\.lifecycle\.(workflow|service)\.(started|completed)/)

      rel
    end
  end

  let(:logger_offenders) do
    workflow_and_service_files.filter_map do |path|
      rel = relative.call(path)
      next if logger_allowlist.include?(rel)
      next unless File.read(path).match?(/Rails\.logger\.(debug|info|warn|error)/)

      rel
    end
  end

  let(:audit_persist_offenders) do
    workflow_and_service_files.filter_map do |path|
      source = File.read(path)
      next unless source.match?(/Audit::Event\.(create|insert|update|destroy)|command_tower_audit_events/)

      relative.call(path)
    end
  end

  it "does not let workflows or services establish execution boundaries" do
    expect(boundary_offenders).to eq([])
  end

  it "does not let workflows or services instrument ASN directly" do
    expect(instrument_offenders).to eq([])
  end

  it "does not let leaf workflows or services publish canonical lifecycle names" do
    expect(lifecycle_offenders).to eq([])
  end

  it "does not let workflows or services use generalized Rails.logger observation" do
    expect(logger_offenders).to eq([])
  end

  it "does not let workflows or services persist audit rows directly" do
    expect(audit_persist_offenders).to eq([])
  end
end
