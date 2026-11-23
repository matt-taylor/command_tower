# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::UI::Config, :aggregate_failures do
  subject(:config) { described_class.new }

  it "is mounted as CommandTower.config.ui" do
    expect(CommandTower::Configuration::Config.new.ui).to be_a(described_class)
  end

  describe "defaults" do
    it "keeps hosts booting unchanged" do
      expect(config.default_zone).to eq("UTC")
      expect(config.image_hosts).to eq([])
    end
  end

  describe "#default_zone" do
    it "accepts a TZInfo identifier" do
      config.default_zone = "America/Los_Angeles"
      expect(config.default_zone).to eq("America/Los_Angeles")
    end

    it "rejects an unknown identifier" do
      expect { config.default_zone = "Mars/Olympus" }.to raise_error(ClassComposer::ValidatorError)
    end

    it "rejects a non-string" do
      expect { config.default_zone = :utc }.to raise_error(ClassComposer::ValidatorError)
    end
  end

  describe "#image_hosts" do
    it "lowercases and IDN-normalizes exact hosts" do
      config.image_hosts = ["Images.Example.COM", "bücher.example", "images.example.com"]
      expect(config.image_hosts).to eq(["images.example.com", "xn--bcher-kva.example"])
    end

    it "rejects entries that are not bare hosts" do
      ["https://example.com", "*.example.com", "example.com/a", "example.com:443"].each do |bad|
        expect { config.image_hosts = [bad] }.to raise_error(ClassComposer::ValidatorError)
      end
    end

    it "rejects a non-array" do
      expect { config.image_hosts = "example.com" }.to raise_error(ClassComposer::ValidatorError)
    end
  end
end
