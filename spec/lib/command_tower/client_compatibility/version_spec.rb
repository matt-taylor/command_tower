# frozen_string_literal: true

RSpec.describe CommandTower::ClientCompatibility::Version do
  describe ".normalize" do
    context "with a strictly valid MAJOR.MINOR.PATCH version" do
      subject(:result) { described_class.normalize("1.2.3") }

      it "returns the unchanged version string" do
        expect(result).to eq("1.2.3")
      end
    end

    context "with a leading lowercase v" do
      subject(:result) { described_class.normalize("v1.2.3") }

      it "strips the leading v" do
        expect(result).to eq("1.2.3")
      end
    end

    context "with a leading uppercase V" do
      subject(:result) { described_class.normalize("V1.2.3") }

      it "strips the leading V" do
        expect(result).to eq("1.2.3")
      end
    end

    context "with a dot-delimited prerelease tail" do
      subject(:result) { described_class.normalize("1.2.3.beta.1") }

      it "accepts the prerelease shape" do
        expect(result).to eq("1.2.3.beta.1")
      end
    end

    context "with surrounding whitespace" do
      subject(:result) { described_class.normalize("  1.2.3  ") }

      it "trims before validating" do
        expect(result).to eq("1.2.3")
      end
    end

    context "with a partial version Gem::Version would accept" do
      subject(:result) { described_class.normalize("1") }

      it "rejects it as malformed, not as valid-but-low" do
        expect(result).to be_nil
      end
    end

    context "with a two-segment partial version" do
      subject(:result) { described_class.normalize("1.2") }

      it "rejects it as malformed" do
        expect(result).to be_nil
      end
    end

    context "with build metadata" do
      subject(:result) { described_class.normalize("1.2.3+build") }

      it "rejects it as malformed" do
        expect(result).to be_nil
      end
    end

    context "with a hyphenated prerelease token" do
      subject(:result) { described_class.normalize("1.2.3-beta") }

      it "rejects it as malformed" do
        expect(result).to be_nil
      end
    end

    context "with whitespace inside the version" do
      subject(:result) { described_class.normalize("1.2 .3") }

      it "rejects it as malformed" do
        expect(result).to be_nil
      end
    end

    context "with an empty prerelease segment" do
      subject(:result) { described_class.normalize("1.2.3.") }

      it "rejects it as malformed" do
        expect(result).to be_nil
      end
    end

    context "with a whitespace-only value" do
      subject(:result) { described_class.normalize("   ") }

      it "treats it as missing identity" do
        expect(result).to be_nil
      end
    end

    context "with nil" do
      subject(:result) { described_class.normalize(nil) }

      it "treats it as missing identity" do
        expect(result).to be_nil
      end
    end
  end

  describe ".valid?" do
    it "is true for a strictly valid version" do
      expect(described_class.valid?("1.2.3")).to be(true)
    end

    it "is false for a partial version" do
      expect(described_class.valid?("1.2")).to be(false)
    end
  end

  describe ".parse" do
    it "returns a comparable Gem::Version for a strictly valid version" do
      expect(described_class.parse("1.2.3")).to eq(Gem::Version.new("1.2.3"))
    end

    it "returns nil for a malformed version instead of constructing a loose Gem::Version" do
      expect(described_class.parse("1.2")).to be_nil
    end
  end
end
