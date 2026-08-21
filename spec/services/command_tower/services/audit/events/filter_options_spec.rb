# frozen_string_literal: true

RSpec.describe CommandTower::Services::Audit::Events::FilterOptions do
  describe ".call" do
    context "when viewer_scope is admin" do
      subject(:result) { described_class.call(viewer_scope: :admin) }

      it { expect(result).to be_success }

      it "projects admin event names with labels and tags from the live registry" do
        expect(result.data[:event_names].find { |entry| entry[:value] == "session_created" }).to include(
          value: "session_created",
          label: "Session created",
          tags: %w[authentication security session]
        )
      end

      it "projects attribution modes from the ledger contract" do
        expect(result.data[:attribution_modes].map { |entry| entry[:value] }).to eq(
          CommandTower::Audit::Event::ATTRIBUTION_MODES
        )
      end

      it "projects subjectTypes from registry subject_type metadata" do
        expect(result.data[:subject_types]).to include(value: "User", label: "User")
        expect(result.data[:subject_types].map { |entry| entry[:value] }).not_to include("")
      end
    end

    context "when viewer_scope is me" do
      subject(:result) { described_class.call(viewer_scope: :me) }

      it { expect(result).to be_success }

      it "limits me catalog to user_history definitions and omits attribution modes" do
        expect(result.data[:event_names].map { |entry| entry[:value] }).to include("password_changed")
        expect(result.data[:event_names].map { |entry| entry[:value] }).not_to include(
          "session_created",
          "announcement_produced"
        )
        expect(result.data[:attribution_modes]).to eq([])
        expect(result.data[:subject_types].map { |entry| entry[:value] }).to include("User")
      end
    end

    context "when a host registers an additive audit event" do
      before do
        CommandTower.config.registry.audit.event :pickem_wager_overridden do |event|
          event.label = "Wager overridden"
          event.tags = %w[Pickem Wager Commissioner]
          event.subject_type = "Pickem::Wager"
          event.user_history = false
        end
      end

      after { CommandTower.config.registry.audit.reset_host_definitions! }

      subject(:result) { described_class.call(viewer_scope: :admin) }

      it "includes host-registered event tags and subject types without FE involvement" do
        expect(result.data[:event_names].find { |entry| entry[:value] == "pickem_wager_overridden" }).to include(
          value: "pickem_wager_overridden",
          label: "Wager overridden",
          tags: %w[commissioner pickem wager]
        )
        expect(result.data[:subject_types]).to include(value: "Pickem::Wager", label: "Pickem::Wager")
      end
    end
  end
end
