# frozen_string_literal: true

RSpec.describe CommandTower::Services::Audit::Events::FilterOptions do
  describe ".call" do
    it "projects admin event names with labels and tags from the live registry" do
      result = described_class.call(viewer_scope: :admin)

      expect(result).to be_success
      session = result.data[:event_names].find { |entry| entry[:value] == "session_created" }
      expect(session).to include(
        value: "session_created",
        label: "Session created",
        tags: %w[authentication security session]
      )
      expect(result.data[:attribution_modes].map { |entry| entry[:value] }).to eq(
        CommandTower::Audit::Event::ATTRIBUTION_MODES
      )
    end

    it "limits me catalog to user_history definitions and omits attribution modes" do
      result = described_class.call(viewer_scope: :me)

      expect(result).to be_success
      values = result.data[:event_names].map { |entry| entry[:value] }
      expect(values).to include("password_changed")
      expect(values).not_to include("session_created", "announcement_produced")
      expect(result.data[:attribution_modes]).to eq([])
      expect(result.data[:subject_types].map { |entry| entry[:value] }).to include("User")
    end

    it "projects subjectTypes from registry subject_type metadata" do
      result = described_class.call(viewer_scope: :admin)

      expect(result).to be_success
      expect(result.data[:subject_types]).to include(value: "User", label: "User")
      expect(result.data[:subject_types].map { |entry| entry[:value] }).not_to include("")
    end

    it "includes host-registered event tags and subject types without FE involvement" do
      CommandTower.config.registry.audit.event :pickem_wager_overridden do |event|
        event.label = "Wager overridden"
        event.tags = %w[Pickem Wager Commissioner]
        event.subject_type = "Pickem::Wager"
        event.user_history = false
      end

      result = described_class.call(viewer_scope: :admin)
      host = result.data[:event_names].find { |entry| entry[:value] == "pickem_wager_overridden" }
      expect(host).to include(
        value: "pickem_wager_overridden",
        label: "Wager overridden",
        tags: %w[commissioner pickem wager]
      )
      expect(result.data[:subject_types]).to include(value: "Pickem::Wager", label: "Pickem::Wager")
    ensure
      CommandTower.config.registry.audit.reset_host_definitions!
    end
  end
end
