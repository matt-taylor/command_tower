# frozen_string_literal: true

RSpec.describe "CommandTower eventing architecture" do
  let(:engine_root) { CommandTower::Engine.root }
  let(:events_source) { File.read(engine_root.join("lib/command_tower/events.rb")) }
  let(:subscriber_source) { File.read(engine_root.join("lib/command_tower/logging/subscriber.rb")) }

  let(:event_bus_offenders) do
    Dir[engine_root.join("{app,lib}/**/*.rb").to_s].filter_map do |path|
      next if path.end_with?("/events.rb")

      path.to_s if File.read(path).match?(/EventBus|NotificationsBus/)
    end
  end

  it { expect(event_bus_offenders).to eq([]) }

  it "does not rescue StandardError around ASN publication" do
    expect(events_source).to include("ActiveSupport::Notifications.instrument")
    expect(events_source).not_to match(/instrument\([^\n]+\)\s*rescue StandardError/m)
    expect(events_source).not_to include("rescue StandardError")
  end

  let(:logging_sources) do
    Dir[engine_root.join("lib/command_tower/logging/*.rb").to_s].map { |path| File.read(path) }
  end

  it "does not JSON-encode logging materialization" do
    logging_sources.each do |source|
      expect(source).not_to include("JSON.generate")
      expect(source).not_to include("to_json")
    end
  end

  it "uses ActiveSupport::Notifications as the only publisher" do
    expect(events_source).to include("ActiveSupport::Notifications.instrument")
    expect(events_source).not_to include("Thread.current")
  end

  it "publishes structured audit through Events rather than a second bus" do
    expect(events_source).to include("def publish_audit")
    expect(event_bus_offenders).to eq([])
    expect(Dir[engine_root.join("{app,lib}/**/*.rb").to_s].none? { |path| File.read(path).include?("AuditEventBus") }).to eq(true)
  end

  it "always publishes lifecycle pairs independent of logger state" do
    expect(events_source).to include("publish_lifecycle(layer:, phase: :started")
    expect(events_source).to include("phase: :completed")
    expect(events_source).not_to include("Rails.logger")
    expect(events_source).not_to include("logger.silence")
    expect(events_source).not_to match(/if log_lifecycle/)
  end

  it "projects logs instead of forwarding the ASN payload" do
    expect(subscriber_source).to include("Projection.call")
    expect(subscriber_source).not_to include("payload.dup")
  end
end
