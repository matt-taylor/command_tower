# frozen_string_literal: true

RSpec.describe CommandTower::Clients::ScopedClient do
  let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
  let(:provider) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }
  let(:user) { Object.new }

  describe "#initialize" do
    it "raises ConfigurationError when provider is missing" do
      expect { described_class.new(provider: nil) }.to raise_error(
        CommandTower::Clients::Errors::ConfigurationError,
        "provider is required"
      )
    end
  end

  describe "#enforce_authentication!" do
    subject(:invoke) { scoped.enforce_authentication! }

    let(:scoped) { described_class.new(provider: provider, user: user) }

    before do
      allow(provider).to receive(:enforce_authentication!).and_call_original
    end

    it "delegates opaque scope kwargs to the provider" do
      invoke

      expect(provider).to have_received(:enforce_authentication!).with(user: user)
    end
  end

  describe "#execute" do
    subject(:result) { scoped.execute(request) }

    let(:scoped) { described_class.new(provider: provider, access_token: "direct") }
    let(:request) do
      CommandTower::Clients::Transport::Request.build(
        method: :get,
        url: "/items/1"
      )
    end

    before do
      allow(provider).to receive(:execute).and_call_original
    end

    it "delegates to the provider with itself as context" do
      result

      expect(provider).to have_received(:execute).with(request, context: scoped)
    end
  end

  describe "#decode_response" do
    subject(:decoded) { scoped.decode_response(response) }

    let(:scoped) { described_class.new(provider: provider, access_token: "direct") }
    let(:response) do
      CommandTower::Clients::Transport::Response.build(
        status: 200,
        body: "raw-body"
      )
    end

    before do
      allow(provider).to receive(:decode_response).and_call_original
    end

    it "delegates to the provider" do
      expect(decoded).to be_a(CommandTower::Clients::DecodedResponse)
      expect(decoded.payload).to eq("raw-body")
      expect(provider).to have_received(:decode_response).with(response)
    end
  end

  describe "namespace discovery" do
    let(:provider) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }
    let(:scoped) { described_class.new(provider: provider, access_token: "tok") }
    let(:proxy) { provider.resolve_namespace!(:catalog) }

    context "when building endpoints for the same scoped client" do
      let(:first) { proxy.build_endpoint(:fetch, client: scoped) }
      let(:second) { proxy.build_endpoint(:fetch, client: scoped) }

      it "builds a fresh endpoint instance per call bound to the scoped client" do
        expect(first).to be_a(CommandTower::Clients::DiscoveryFixtureProvider::Catalog::Fetch)
        expect(second).to be_a(CommandTower::Clients::DiscoveryFixtureProvider::Catalog::Fetch)
        expect(first).not_to equal(second)
        expect(first.client).to equal(scoped)
      end
    end

    context "with distinct scoped clients" do
      let(:other) { described_class.new(provider: provider, access_token: "other") }

      it "does not share endpoint instances across distinct scoped clients" do
        expect(proxy.build_endpoint(:fetch, client: scoped).client).to equal(scoped)
        expect(proxy.build_endpoint(:fetch, client: other).client).to equal(other)
      end
    end
  end
end
