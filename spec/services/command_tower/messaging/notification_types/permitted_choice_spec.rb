# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::NotificationTypes::PermittedChoice do
  let(:universe) { CommandTower::Messaging::NotificationTypes::URGENCY_LEVELS }

  describe ".from" do
    context "when raw is nil" do
      subject(:choice) { described_class.from(nil, fallback_default: "normal") }

      it "is fixed on the fallback default" do
        expect(choice).to eq(described_class.new(default: "normal", allowed: %w[normal]))
      end
    end

    context "when raw is a hash with string keys and symbol values" do
      subject(:choice) { described_class.from({ "default" => :normal, "allowed" => :all }, fallback_default: "normal") }

      it "coerces default to a string and :all to \"all\"" do
        expect(choice).to eq(described_class.new(default: "normal", allowed: "all"))
      end
    end

    context "when raw is not a hash" do
      subject(:choice) { described_class.from(%w[normal], fallback_default: "normal") }

      it "returns the value unchanged" do
        expect(choice).to eq(%w[normal])
      end
    end

    context "when raw has no default" do
      subject(:choice) { described_class.from({ allowed: %w[normal] }, fallback_default: "normal") }

      it "keeps a nil default for the validator to report" do
        expect(choice.default).to be_nil
      end
    end
  end

  describe "#mode" do
    it "is fixed for one permitted value" do
      expect(described_class.new(default: "normal", allowed: %w[normal]).mode).to eq(:fixed)
    end

    it "is restricted for an explicit list of more than one" do
      expect(described_class.new(default: "normal", allowed: %w[normal critical]).mode).to eq(:restricted)
    end

    it "is full for \"all\"" do
      expect(described_class.new(default: "normal", allowed: "all").mode).to eq(:full)
    end
  end

  describe "#permitted" do
    it "returns the explicit list" do
      expect(described_class.new(default: "normal", allowed: %w[normal]).permitted(universe)).to eq(%w[normal])
    end

    it "returns the whole universe for \"all\"" do
      expect(described_class.new(default: "normal", allowed: "all").permitted(universe)).to eq(universe)
    end
  end

  describe "#selectable?" do
    it "is false when fixed" do
      expect(described_class.new(default: "normal", allowed: %w[normal]).selectable?(universe)).to be(false)
    end

    it "is true when restricted" do
      expect(described_class.new(default: "normal", allowed: %w[normal critical]).selectable?(universe)).to be(true)
    end

    it "is true when full over a larger universe" do
      expect(described_class.new(default: "normal", allowed: "all").selectable?(universe)).to be(true)
    end

    it "is false when full over a one-entry universe" do
      expect(described_class.new(default: "default", allowed: "all").selectable?(%w[default])).to be(false)
    end
  end
end
