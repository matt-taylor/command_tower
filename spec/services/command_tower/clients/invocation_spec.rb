# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Invocation do
  let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
  let(:provider) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }

  before do
    CommandTower::Clients.reset_providers!
    CommandTower::Clients.seed_provider!(:discovery_fixture_provider, provider)
  end

  after do
    CommandTower::Clients.reset_providers!
  end

  describe ".method_missing" do
    context "when resolving a seeded provider with scope kwargs" do
      subject(:scoped) { CommandTower::Clients.discovery_fixture_provider(user: user) }

      let(:user) { Object.new }

      it "returns a ScopedClient bound to the memoized provider" do
        expect(scoped).to be_a(CommandTower::Clients::ScopedClient)
        expect(scoped.provider).to equal(provider)
        expect(scoped.user).to equal(user)
      end
    end

    context "when resolving with opaque access_token scope" do
      subject(:scoped) do
        CommandTower::Clients.discovery_fixture_provider(access_token: "direct-token")
      end

      it "returns a ScopedClient with opaque access_token scope" do
        expect(scoped).to be_a(CommandTower::Clients::ScopedClient)
        expect(scoped[:access_token]).to eq("direct-token")
        expect(scoped.user).to be_nil
      end
    end

    context "when resolving the same provider twice" do
      let(:first) { CommandTower::Clients.discovery_fixture_provider(access_token: "a") }
      let(:second) { CommandTower::Clients.discovery_fixture_provider(access_token: "b") }

      before { first }

      it "reuses the memoized provider instance" do
        expect(first.provider).to equal(second.provider)
        expect(first).not_to equal(second)
        expect(first[:access_token]).not_to eq(second[:access_token])
      end
    end

    context "when the provider name is unknown" do
      subject(:invoke) { CommandTower::Clients.unknown_provider(user: nil) }

      it "raises NoMethodError" do
        expect { invoke }.to raise_error(NoMethodError)
      end
    end
  end

  describe ".provider_for!" do
    subject(:resolved) { CommandTower::Clients.provider_for!(:discovery_fixture_provider) }

    it "memoizes by normalized provider name" do
      expect(resolved).to equal(provider)
      expect(CommandTower::Clients.provider_for!("DiscoveryFixtureProvider")).to equal(provider)
    end
  end
end
