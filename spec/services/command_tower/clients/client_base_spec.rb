# frozen_string_literal: true

RSpec.describe CommandTower::Clients::ClientBase do
  let(:request) do
    CommandTower::Clients::Transport::Request.build(
      method: :get,
      url: "https://example.test/resource",
      headers: { "X-Request" => "1" }
    )
  end

  describe "#initialize" do
    context "when transport is missing" do
      subject(:invoke) { described_class.new(transport: nil) }

      it "raises when transport is missing" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          "transport is required"
        )
      end
    end

    context "when transport is not injected" do
      let(:first_client) { described_class.new }
      let(:second_client) { described_class.new }

      it "creates a new FaradayAdapter per ClientBase by default" do
        expect(first_client.instance_variable_get(:@transport)).to be_a(
          CommandTower::Clients::Transport::FaradayAdapter
        )
        expect(second_client.instance_variable_get(:@transport)).to be_a(
          CommandTower::Clients::Transport::FaradayAdapter
        )
        expect(first_client.instance_variable_get(:@transport)).not_to equal(
          second_client.instance_variable_get(:@transport)
        )
      end
    end

    context "when a fake transport is injected" do
      let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
      let(:client) { described_class.new(transport: transport) }

      it "preserves an injected fake transport" do
        expect(client.instance_variable_get(:@transport)).to equal(transport)
      end
    end
  end

  describe "#execute" do
    context "when the request URL is absolute" do
      subject(:result) { client.execute(request) }

      let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
      let(:client) { CommandTower::Clients::AbsoluteOnlyFixtureProvider.new(transport: transport) }
      let(:request) do
        CommandTower::Clients::Transport::Request.build(
          method: :get,
          url: "https://signed.example/callback?token=1"
        )
      end

      it "preserves the absolute URL without requiring base_url" do
        expect(result).to be_success
        expect(transport.calls.first.url).to eq("https://signed.example/callback?token=1")
      end
    end

    context "when the request URL is relative and base_url is blank" do
      subject(:invoke) { client.execute(request) }

      let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
      let(:client) { CommandTower::Clients::AbsoluteOnlyFixtureProvider.new(transport: transport) }
      let(:request) do
        CommandTower::Clients::Transport::Request.build(method: :get, url: "/relative")
      end

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /base_url is required/
        )
      end
    end

    context "when the request is not a Transport::Request" do
      let(:client) { described_class.new(transport: CommandTower::Clients::SpecSupport::FakeTransport.new) }

      subject(:invoke) { client.execute(Object.new) }

      it "raises when request is not a Transport::Request" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /Transport::Request/
        )
      end
    end

    context "when the transport returns a successful response" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: "ok", duration_ms: 4)
        end
      end
      let(:client) { described_class.new(transport: transport) }

      subject(:result) { client.execute(request) }

      it "returns a successful ClientResult with Transport::Response output" do
        expect(result).to be_success
        expect(result.output).to be_a(CommandTower::Clients::Transport::Response)
        expect(result.output.status).to eq(200)
        expect(result.output.body).to eq("ok")
        expect(result.error).to be_nil
        expect(result.metadata).to include(status: 200, duration_ms: 4)
      end
    end

    context "when the transport returns HTTP non-success" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 503, body: "unavailable", duration_ms: 2)
        end
      end
      let(:client) { described_class.new(transport: transport) }

      subject(:result) { client.execute(request) }

      it "returns a failed ClientResult for HTTP non-success" do
        expect(result).to be_failure
        expect(result.error).to be_a(CommandTower::Clients::Errors::UpstreamError)
        expect(result.error.details).to eq(status: 503)
        expect(result.output).to be_a(CommandTower::Clients::Transport::Response)
        expect(result.metadata).to include(status: 503, duration_ms: 2)
      end
    end

    context "when the transport raises a connection failure" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          raise CommandTower::Clients::Transport::Error, "connection refused"
        end
      end
      let(:client) { described_class.new(transport: transport) }

      subject(:result) { client.execute(request) }

      it "returns a failed ClientResult for transport timeout/connection failures" do
        expect(result).to be_failure
        expect(result.error).to be_a(CommandTower::Clients::Errors::UpstreamError)
        expect(result.error.message).to eq("connection refused")
        expect(result.metadata).to include(:duration_ms)
        expect(result.metadata).not_to have_key(:status)
      end
    end

    context "when the transport returns an invalid response shape" do
      let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new { |_req| :not_a_response } }
      let(:client) { described_class.new(transport: transport) }

      subject(:invoke) { client.execute(request) }

      it "raises when transport returns an invalid response shape" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /Transport::Response/
        )
      end
    end

    context "when provider default headers and authentication hooks apply" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: "")
        end
      end
      let(:client) do
        CommandTower::Clients::SpecSupport::FakeProviderClient.new(
          transport: transport,
          default_headers: { "X-Default" => "d" },
          auth_header: "Bearer token"
        )
      end

      before { client.execute(request) }

      subject(:sent) { transport.calls.sole }

      it "applies provider default headers and authentication hooks" do
        expect(sent.headers).to include(
          "X-Default" => "d",
          "X-Request" => "1",
          "Authorization" => "Bearer token"
        )
      end
    end

    context "when request headers override default headers" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: "")
        end
      end
      let(:client) do
        CommandTower::Clients::SpecSupport::FakeProviderClient.new(
          transport: transport,
          default_headers: { "X-Default" => "default" }
        )
      end
      let(:override_request) do
        CommandTower::Clients::Transport::Request.build(
          method: :get,
          url: "https://example.test/resource",
          headers: { "X-Default" => "override" }
        )
      end

      before { client.execute(override_request) }

      it "lets request headers override default headers" do
        expect(transport.calls.sole.headers["X-Default"]).to eq("override")
      end
    end

    context "when the provider maps provider errors on non-success" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 401, body: "no")
        end
      end
      let(:client) { CommandTower::Clients::SpecSupport::FakeProviderClient.new(transport: transport) }

      subject(:result) { client.execute(request) }

      it "uses provider map_provider_error on non-success" do
        expect(result).to be_failure
        expect(result.error.message).to eq("fake provider failed with 401")
        expect(result.error.details).to eq(status: 401, provider: "fake")
      end
    end

    context "when the transport omits duration_ms" do
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: "ok", duration_ms: nil)
        end
      end
      let(:client) { described_class.new(transport: transport) }

      subject(:result) { client.execute(request) }

      it "measures duration_ms when the transport omits it" do
        expect(result.metadata[:duration_ms]).to be_a(Integer)
        expect(result.metadata[:duration_ms]).to be >= 0
      end
    end
  end

  describe ".resolve_provider!" do
    subject(:resolved) { described_class.resolve_provider!(name) }

    context "when the provider exists under Clients" do
      let(:name) { :DiscoveryFixtureProvider }

      it "returns the ClientBase subclass" do
        expect(resolved).to eq(CommandTower::Clients::DiscoveryFixtureProvider)
        expect(resolved).to be < CommandTower::Clients::ClientBase
      end
    end

    context "when the name is snake_case" do
      let(:name) { "discovery_fixture_provider" }

      it { is_expected.to eq(CommandTower::Clients::DiscoveryFixtureProvider) }
    end

    context "when the provider constant is missing" do
      subject(:invoke) { described_class.resolve_provider!(:MissingProvider) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /missing provider: expected CommandTower::Clients::MissingProvider/
        )
      end
    end

    context "when the constant does not inherit ClientBase" do
      subject(:invoke) { described_class.resolve_provider!(:DiscoveryFixturePlain) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /invalid provider inheritance: expected CommandTower::Clients::DiscoveryFixturePlain < CommandTower::Clients::ClientBase/
        )
      end
    end

    context "when the name is blank" do
      subject(:invoke) { described_class.resolve_provider!("") }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /discovery name must be present/
        )
      end
    end
  end

  describe "#resolve_namespace!" do
    let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
    let(:client) { CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport) }

    subject(:proxy) { client.resolve_namespace!(name) }

    context "when the namespace module exists" do
      let(:name) { :Catalog }

      it "returns a NamespaceProxy bound to the client" do
        expect(proxy).to be_a(CommandTower::Clients::NamespaceProxy)
        expect(proxy.client).to equal(client)
        expect(proxy.namespace_module).to eq(CommandTower::Clients::DiscoveryFixtureProvider::Catalog)
        expect(proxy.namespace_module).to be_instance_of(Module)
      end

      it "memoizes NamespaceProxy for the same name" do
        expect(client.resolve_namespace!("catalog")).to equal(proxy)
      end
    end

    context "when the namespace constant is missing" do
      subject(:invoke) { client.resolve_namespace!(:MissingNs) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /missing namespace: expected CommandTower::Clients::DiscoveryFixtureProvider::MissingNs/
        )
      end
    end

    context "when the constant is a Class instead of a Module" do
      subject(:invoke) { client.resolve_namespace!(:CatalogAsClass) }

      it "raises DiscoveryError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::DiscoveryError,
          /invalid namespace: expected CommandTower::Clients::DiscoveryFixtureProvider::CatalogAsClass to be a Module/
        )
      end
    end

    context "under concurrent resolve" do
      let(:proxies) { Array.new(20) }
      let(:threads) do
        20.times.map do |index|
          Thread.new { proxies[index] = client.resolve_namespace!(:Catalog) }
        end
      end

      before { threads.each(&:join) }

      it "does not corrupt namespace memoization" do
        expect(proxies.uniq.size).to eq(1)
        expect(proxies.first).to be_a(CommandTower::Clients::NamespaceProxy)
      end

      context "when resolving endpoints concurrently" do
        let(:namespace) { client.resolve_namespace!(:Catalog) }
        let(:endpoints) { Array.new(20) }
        let(:endpoint_threads) do
          20.times.map do |index|
            Thread.new { endpoints[index] = namespace.resolve_endpoint!(:Fetch) }
          end
        end

        before { endpoint_threads.each(&:join) }

        it "does not corrupt endpoint memoization" do
          expect(endpoints.uniq.size).to eq(1)
          expect(endpoints.first.client).to equal(client)
        end
      end
    end
  end

  describe "#decode_response" do
    let(:client) { described_class.new(transport: CommandTower::Clients::SpecSupport::FakeTransport.new) }

    context "when decoding a response body" do
      let(:response) { CommandTower::Clients::Transport::Response.build(status: 200, body: "<xml/>") }

      subject(:decoded) { client.decode_response(response) }

      it "returns the raw response body as payload" do
        expect(decoded).to be_a(CommandTower::Clients::DecodedResponse)
        expect(decoded.payload).to eq("<xml/>")
        expect(decoded.provider_metadata).to eq({})
      end
    end

    context "when the payload must not be a Transport::Response" do
      let(:response) { CommandTower::Clients::Transport::Response.build(status: 200, body: '{"a":1}') }

      subject(:decoded) { client.decode_response(response) }

      it "never returns Transport::Response as the payload" do
        expect(decoded.payload).not_to be_a(CommandTower::Clients::Transport::Response)
      end
    end

    context "when the body looks like JSON" do
      let(:response) { CommandTower::Clients::Transport::Response.build(status: 200, body: '{"a":1}') }

      before { expect(JSON).not_to receive(:parse) }

      subject(:decoded) { client.decode_response(response) }

      it "does not assume JSON" do
        expect(decoded.payload).to eq('{"a":1}')
      end
    end
  end
end
