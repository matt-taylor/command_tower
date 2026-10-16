# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::SettingsProjection, :messaging_preferences do
  let(:user) { create(:user) }
  let(:destinations) { { "push" => { state: "editable", effective: true } } }
  let(:blocks) do
    CommandTower::Messaging::Preferences::EffectiveChoice.call(declaration:, stored: nil)
  end
  let(:settings) do
    described_class.for_notification(
      declaration:,
      blocks:,
      destinations:,
    )
  end

  describe ".for_notification" do
    context "with an incomplete picks reminder-shaped declaration" do
      let(:declaration) do
        build_notification_type_declaration(
          key: "incomplete_wager",
          allowed_channels: %w[email push],
          default_channels: %w[email push],
          urgency: { default: "normal", allowed: %w[normal time_sensitive] },
          sound: { default: "default", allowed: %w[default] },
        )
      end

      before { register_and_seal_notification_types(declaration) }

      it "projects selectable urgency only without critical in options" do
        expect(settings.length).to eq(1)
        expect(settings.first[:key]).to eq("urgency")
        expect(settings.first[:channel_key]).to eq("push")
        expect(settings.first[:control]).to eq("single_select")
        expect(settings.first[:options].map { |o| o[:value] }).to eq(%w[normal time_sensitive])
        expect(settings.first[:options].map { |o| o[:value] }).not_to include("critical")
      end

      it "matches legacy urgency effective id" do
        expect(settings.first[:effective]).to eq(blocks[:urgency][:effective])
      end
    end

    context "with multiple permitted sounds" do
      let(:host_sounds) do
        [
          { id: "chime", label: "Chime", asset: "chime.wav" },
          { id: "bell", label: "Bell", asset: "bell.wav" },
        ]
      end

      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          inbox_available: false,
          deep_link_required: true,
          urgency: { default: "normal", allowed: %w[normal] },
          sound: { default: "default", allowed: "all" },
        )
      end

      let(:sound) { settings.find { |entry| entry[:key] == "sound" } }

      around do |example|
        previous = CommandTower.config.messaging.sounds
        CommandTower.config.messaging.sounds = host_sounds
        example.run
      ensure
        CommandTower.config.messaging.sounds = previous
      end

      before { register_and_seal_notification_types(declaration) }

      it "includes a sound single_select with catalog labels and null descriptions" do
        expect(sound).to include(
          channel_key: "push",
          control: "single_select",
          label: "Sound",
          description: nil,
        )
        expect(sound[:options]).to contain_exactly(
          { value: "default", label: "System Default", description: nil },
          { value: "chime", label: "Chime", description: nil },
          { value: "bell", label: "Bell", description: nil },
        )
      end

      it "matches legacy sound effective id" do
        expect(sound[:effective]).to eq(blocks[:sound][:effective])
      end
    end

    context "with a single permitted sound" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          sound: { default: "default", allowed: %w[default] },
        )
      end

      before { register_and_seal_notification_types(declaration) }

      it "omits sound from settings" do
        expect(settings.map { |entry| entry[:key] }).not_to include("sound")
      end
    end

    context "when urgency and sound are both selectable" do
      let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[push],
          default_channels: %w[push],
          inbox_available: false,
          deep_link_required: true,
          urgency: { default: "normal", allowed: %w[normal time_sensitive] },
          sound: { default: "default", allowed: "all" },
        )
      end

      around do |example|
        previous = CommandTower.config.messaging.sounds
        CommandTower.config.messaging.sounds = host_sounds
        example.run
      ensure
        CommandTower.config.messaging.sounds = previous
      end

      before { register_and_seal_notification_types(declaration) }

      it "preserves server-defined order with urgency before sound" do
        expect(settings.map { |entry| entry[:key] }).to eq(%w[urgency sound])
      end
    end

    context "when push is not on the type" do
      let(:declaration) do
        build_notification_type_declaration(
          allowed_channels: %w[email],
          default_channels: %w[email],
          urgency: { default: "normal", allowed: %w[normal time_sensitive] },
        )
      end
      let(:destinations) { { "email" => { state: "editable", effective: true } } }

      before { register_and_seal_notification_types(declaration) }

      it "returns an empty settings array" do
        expect(settings).to eq([])
      end
    end
  end

  describe ".build" do
    let(:definition) do
      described_class::SingleSelectDefinition.new(
        key: "example_choice",
        channel_key: "email",
        label: "Example",
        description: "Member-facing helper",
        effective: "a",
        options: [
          { value: "a", label: "Option A", description: nil },
          { value: "b", label: "Option B", description: nil },
        ].freeze,
      )
    end

    subject(:settings) { described_class.build([definition]) }

    it "projects a generic non-push channel single_select without delivery behavior" do
      expect(settings.length).to eq(1)
      expect(settings.first).to include(
        key: "example_choice",
        channel_key: "email",
        control: "single_select",
        effective: "a",
      )
    end
  end

  describe CommandTower::Messaging::Preferences::SettingControls do
    it "rejects boolean and multi_select controls" do
      expect { described_class.validate_implemented!("boolean") }
        .to raise_error(described_class::UnsupportedControlError, /not implemented/)
      expect { described_class.validate_implemented!("multi_select") }
        .to raise_error(described_class::UnsupportedControlError, /not implemented/)
    end
  end

  describe "critical urgency copy" do
    let(:declaration) do
      build_notification_type_declaration(
        allowed_channels: %w[push],
        default_channels: %w[push],
        inbox_available: false,
        deep_link_required: true,
        urgency: { default: "normal", allowed: "all" },
        sound: { default: "default", allowed: %w[default] },
      )
    end

    let(:critical_option) do
      settings.first[:options].find { |option| option[:value] == "critical" }
    end

    before { register_and_seal_notification_types(declaration) }

    it "does not claim Critical Alerts or OS bypass behavior" do
      expect(critical_option[:description]).to eq(
        "Highest declared urgency. Actual delivery behavior depends on the application and device capabilities.",
      )
      expect(critical_option[:description]).not_to match(/Critical Alerts/i)
      expect(critical_option[:description]).not_to match(/Focus|Do Not Disturb|lock.screen/i)
    end
  end
end
