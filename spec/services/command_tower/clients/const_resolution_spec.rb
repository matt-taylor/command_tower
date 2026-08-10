# frozen_string_literal: true

RSpec.describe CommandTower::Clients::ConstResolution do
  describe ".normalize_name" do
    it "camelizes a snake_case name" do
      expect(described_class.normalize_name("catalog_fixture")).to eq("CatalogFixture")
    end

    it "raises DiscoveryError for a blank name" do
      expect { described_class.normalize_name("") }.to raise_error(
        CommandTower::Clients::Errors::DiscoveryError, /discovery name must be present/
      )
    end
  end

  describe ".const_get!" do
    context "with an existing constant under the parent" do
      subject(:resolved) do
        described_class.const_get!(
          CommandTower::Clients,
          :DiscoveryFixtureProvider,
          expected: "provider"
        )
      end

      it { expect(resolved).to eq(CommandTower::Clients::DiscoveryFixtureProvider) }
    end

    it "raises DiscoveryError when the constant is missing" do
      expect {
        described_class.const_get!(CommandTower::Clients, :MissingThing, expected: "provider")
      }.to raise_error(
        CommandTower::Clients::Errors::DiscoveryError, /missing provider: expected CommandTower::Clients::MissingThing/
      )
    end
  end
end
