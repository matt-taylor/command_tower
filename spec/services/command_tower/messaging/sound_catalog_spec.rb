# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::SoundCatalog do
  let(:host_sounds) { [] }

  around do |example|
    previous = CommandTower.config.messaging.sounds
    example.run
  ensure
    CommandTower.config.messaging.sounds = previous
  end

  before { CommandTower.config.messaging.sounds = host_sounds }

  describe ".entries" do
    context "with no host sounds" do
      it "contains only System Default without an asset" do
        expect(described_class.entries).to eq([{ id: "default", label: "System Default", asset: nil }])
      end
    end

    context "with host sounds using string keys" do
      let(:host_sounds) { [{ "id" => "chime", "label" => "Chime", "asset" => "chime.wav" }] }

      it "lists System Default first, then host entries with symbol keys" do
        expect(described_class.entries).to eq(
          [
            { id: "default", label: "System Default", asset: nil },
            { id: "chime", label: "Chime", asset: "chime.wav" },
          ],
        )
      end
    end

    context "when a host entry tries to redefine default" do
      let(:host_sounds) { [{ id: "default", label: "Mine", asset: "mine.wav" }] }

      it "keeps the engine System Default first" do
        expect(described_class.entries.first).to eq(described_class::SYSTEM_DEFAULT)
      end
    end
  end

  describe ".ids and .fetch" do
    let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

    it "lists the ids" do
      expect(described_class.ids).to eq(%w[default chime])
    end

    it "fetches an entry by id" do
      expect(described_class.fetch(:chime)).to include(asset: "chime.wav")
    end

    it "returns nil for an unknown id" do
      expect(described_class.fetch("bell")).to be_nil
    end
  end

  describe ".validation_errors" do
    subject(:errors) { described_class.validation_errors }

    context "with no host sounds" do
      it { is_expected.to be_empty }
    end

    context "with a valid host sound" do
      let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "chime.wav" }] }

      it { is_expected.to be_empty }
    end

    context "when an id redefines the System Default" do
      let(:host_sounds) { [{ id: "default", label: "Mine", asset: "mine.wav" }] }

      it "reports the reserved id" do
        expect(errors).to eq(['sounds[0] id "default" is reserved for System Default'])
      end
    end

    context "when an id is duplicated" do
      let(:host_sounds) do
        [
          { id: "chime", label: "Chime", asset: "chime.wav" },
          { id: "chime", label: "Chime 2", asset: "chime2.wav" },
        ]
      end

      it "reports the duplicate" do
        expect(errors).to eq(['sounds[1] id "chime" is duplicated'])
      end
    end

    context "when an id is malformed" do
      let(:host_sounds) { [{ id: "Chime-Bell", label: "Chime", asset: "chime.wav" }] }

      it "reports the id format" do
        expect(errors.first).to start_with("sounds[0] id must match")
      end
    end

    context "when a label is blank" do
      let(:host_sounds) { [{ id: "chime", label: " ", asset: "chime.wav" }] }

      it "reports the label" do
        expect(errors).to eq(["sounds[0] label must be present"])
      end
    end

    context "when a custom asset is blank" do
      let(:host_sounds) { [{ id: "chime", label: "Chime", asset: "" }] }

      it "reports the asset" do
        expect(errors).to eq(["sounds[0] asset must be present"])
      end
    end

    %w[chime.wav chime.aiff chime.caf CHIME.WAV].each do |asset|
      context "when the asset is #{asset}" do
        let(:host_sounds) { [{ id: "chime", label: "Chime", asset: }] }

        it { is_expected.to be_empty }
      end
    end

    ["chime", "chime.mp3", "chime.", ".wav"].each do |asset|
      context "when the asset is #{asset.inspect}" do
        let(:host_sounds) { [{ id: "chime", label: "Chime", asset: }] }

        it "reports the unsupported extension" do
          expect(errors).to eq(["sounds[0] asset must end in .wav, .aiff, .caf"])
        end
      end
    end

    context "when an entry is not a hash" do
      let(:host_sounds) { ["chime"] }

      it "reports the entry and leaves it out of entries" do
        expect(errors).to eq(["sounds[0] must be a hash"])
        expect(described_class.ids).to eq(%w[default])
      end
    end
  end
end
