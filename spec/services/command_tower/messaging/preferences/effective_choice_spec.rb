# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Preferences::EffectiveChoice, :messaging_notification_types do
  subject(:blocks) { described_class.call(declaration:, stored:) }

  let(:stored) { nil }
  let(:urgency) { nil }
  let(:sound) { { default: "default", allowed: %w[default] } }
  let(:host_sounds) { [] }
  let(:declaration) do
    build_notification_type_declaration(
      urgency:,
      sound:,
    )
  end

  around do |example|
    previous = CommandTower.config.messaging.sounds
    example.run
  ensure
    CommandTower.config.messaging.sounds = previous
  end

  before { CommandTower.config.messaging.sounds = host_sounds }

  context "with a fixed urgency" do
    it "is not selectable and uses the default" do
      expect(blocks[:urgency]).to include(
        default: "normal",
        allowed: %w[normal],
        selectable: false,
        effective: "normal",
      )
    end
  end

  context "with a restricted urgency" do
    let(:urgency) { { default: "normal", allowed: %w[normal time_sensitive] } }

    it "offers the permitted levels" do
      expect(blocks[:urgency]).to include(selectable: true, allowed: %w[normal time_sensitive], effective: "normal")
    end

    context "when the member stored a permitted level" do
      let(:stored) { CommandTower::Messaging::Preferences::PreferenceState.normalize("urgency" => "time_sensitive") }

      it "uses the stored level" do
        expect(blocks[:urgency][:effective]).to eq("time_sensitive")
      end
    end

    context "when the stored level is no longer permitted" do
      let(:stored) { CommandTower::Messaging::Preferences::PreferenceState.normalize("urgency" => "critical") }

      it "falls back to the declaration default" do
        expect(blocks[:urgency][:effective]).to eq("normal")
      end
    end
  end

  context "with the full urgency catalog" do
    let(:urgency) { { default: "normal", allowed: "all" } }

    it "permits every level" do
      expect(blocks[:urgency][:allowed]).to eq(%w[normal time_sensitive critical])
      expect(blocks[:urgency][:selectable]).to be(true)
    end
  end

  context "with a fixed sound" do
    it "lists System Default without an asset filename" do
      expect(blocks[:sound]).to eq(
        default: "default",
        allowed: [{ id: "default", label: "System Default" }],
        selectable: false,
        effective: "default",
      )
    end
  end

  context "with a full sound catalog" do
    let(:sound) { { default: "default", allowed: "all" } }
    let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

    it "lists registered sounds with labels only" do
      expect(blocks[:sound][:allowed]).to eq(
        [
          { id: "default", label: "System Default" },
          { id: "chime", label: "Chime" },
        ],
      )
      expect(blocks[:sound][:selectable]).to be(true)
    end

    context "when the member stored a registered sound" do
      let(:stored) { CommandTower::Messaging::Preferences::PreferenceState.normalize("sound" => "chime") }

      it "uses the stored sound" do
        expect(blocks[:sound][:effective]).to eq("chime")
      end
    end

    context "when the stored sound is no longer registered" do
      let(:stored) { CommandTower::Messaging::Preferences::PreferenceState.normalize("sound" => "bell") }

      it "falls back to the declaration default" do
        expect(blocks[:sound][:effective]).to eq("default")
      end
    end
  end

  context "when the declaration default is not registered" do
    let(:sound) { { default: "retired", allowed: %w[retired] } }
    let(:stored) { CommandTower::Messaging::Preferences::PreferenceState.normalize("sound" => "retired") }

    it "resolves to System Default" do
      expect(blocks[:sound][:allowed]).to eq([])
      expect(blocks[:sound][:effective]).to eq("default")
    end
  end
end
