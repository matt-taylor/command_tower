# frozen_string_literal: true

RSpec.describe CommandTower::Clients::NamespaceProxy do
  let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
  let(:client) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }
  let(:proxy) do
    described_class.new(
      client: client,
      namespace_module: CommandTower::Clients::DiscoveryFixtureProvider::Catalog
    )
  end

  describe "#initialize" do
    it "raises ConfigurationError when client is missing" do
      expect do
        described_class.new(
          client: nil,
          namespace_module: CommandTower::Clients::DiscoveryFixtureProvider::Catalog
        )
      end.to raise_error(CommandTower::Clients::Errors::ConfigurationError, "client is required")
    end

    it "raises ConfigurationError when namespace_module is missing" do
      expect { described_class.new(client: client, namespace_module: nil) }.to raise_error(
        CommandTower::Clients::Errors::ConfigurationError,
        "namespace_module is required"
      )
    end
  end

  describe "#resolve_endpoint!" do
    subject(:endpoint) { proxy.resolve_endpoint!(name) }

    context "when the endpoint exists" do
      let(:name) { :Fetch }

      it "returns an EndpointBase instance bound to the client" do
        expect(endpoint).to be_a(CommandTower::Clients::DiscoveryFixtureProvider::Catalog::Fetch)
        expect(endpoint).to be_a(CommandTower::Clients::EndpointBase)
        expect(endpoint.client).to equal(client)
      end

      it "memoizes endpoint instances for the same name" do
        expect(proxy.resolve_endpoint!("fetch")).to equal(endpoint)
      end
    end

    context "when the endpoint constant is missing" do
      subject(:invoke) { proxy.resolve_endpoint!(:MissingOp) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /missing endpoint: expected CommandTower::Clients::DiscoveryFixtureProvider::Catalog::MissingOp/
        )
      end
    end

    context "when the constant does not inherit EndpointBase" do
      subject(:invoke) { proxy.resolve_endpoint!(:PlainObject) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /invalid endpoint inheritance: expected CommandTower::Clients::DiscoveryFixtureProvider::Catalog::PlainObject < CommandTower::Clients::EndpointBase/
        )
      end
    end
  end

  describe "#build_endpoint" do
    subject(:endpoint) { proxy.build_endpoint(name, client: other_client) }

    let(:name) { :Fetch }
    let(:other_client) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }

    it "returns a fresh EndpointBase instance bound to the given client" do
      expect(endpoint).to be_a(CommandTower::Clients::DiscoveryFixtureProvider::Catalog::Fetch)
      expect(endpoint.client).to equal(other_client)
    end

    it "does not memoize instances across builds" do
      expect(proxy.build_endpoint(name, client: other_client)).not_to equal(endpoint)
    end

    context "when resolving the endpoint class twice" do
      subject(:first) { proxy.resolve_endpoint_class!(name) }
      let(:second) { proxy.resolve_endpoint_class!(name) }

      before { first }

      it "memoizes the resolved endpoint class" do
        expect(first).to equal(second)
      end
    end
  end
end
