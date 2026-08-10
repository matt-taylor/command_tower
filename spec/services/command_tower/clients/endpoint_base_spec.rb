# frozen_string_literal: true

RSpec.describe CommandTower::Clients::EndpointBase do
  let(:transport) { CommandTower::Clients::SpecSupport::FakeTransport.new }
  let(:client) { CommandTower::Clients::ContractFixtureProvider.new(transport: transport) }

  describe "#initialize" do
    context "when client is missing" do
      subject(:invoke) { described_class.new(client: nil) }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          "client is required"
        )
      end
    end

    context "when client is provided" do
      subject(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::List.new(client: client) }

      it "exposes the client" do
        expect(endpoint.client).to equal(client)
      end
    end
  end

  describe "#call" do
    # Internal orchestration — not the locked product invocation API.

    context "with a dynamic relative path" do
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::Show.new(client: client) }

      subject(:result) { endpoint.call(id: "42") }

      it "builds input from kwargs, resolves the path, and executes through the client" do
        expect(result).to be_success
        expect(transport.calls.size).to eq(1)
        expect(transport.calls.first.method).to eq(:get)
        expect(transport.calls.first.url).to eq("https://example.test/api/v1/items/42")
        expect(transport.calls.first.query).to eq("expand" => "true")
        expect(transport.calls.first.headers).to include("X-Fixture" => "show")
      end

      it "replaces Transport::Response with the deserialized output object" do
        expect(result.output).to eq(
          CommandTower::Clients::ContractFixtureProvider::Items::ShowOutput.new(id: "deserialized")
        )
        expect(result.output).not_to be_a(CommandTower::Clients::Transport::Response)
        expect(result.metadata).to include(status: 200, duration_ms: 1)
      end
    end

    context "with an empty immutable input" do
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::List.new(client: client) }

      subject(:result) { endpoint.call }

      it "constructs the input without kwargs and executes" do
        expect(result).to be_success
        expect(transport.calls.first.url).to eq("https://example.test/api/v1/items")
        expect(transport.calls.first.query).to eq("page" => "1")
        expect(result.output).to eq(
          CommandTower::Clients::ContractFixtureProvider::Items::ListOutput.new(items: [])
        )
      end
    end

    context "with a POST declaration and body serializer" do
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::Create.new(client: client) }

      subject(:result) { endpoint.call(name: "widget") }

      it "maps verb and serialized body onto the transport request" do
        expect(result).to be_success
        expect(transport.calls.first.method).to eq(:post)
        expect(transport.calls.first.url).to eq("https://example.test/api/v1/items")
        expect(transport.calls.first.body).to eq(name: "widget")
      end
    end

    context "when unknown input attributes are provided" do
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::Show.new(client: client) }

      subject(:invoke) { endpoint.call(id: "1", unexpected: true) }

      it "raises ConfigurationError with endpoint context and cause" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /CommandTower::Clients::ContractFixtureProvider::Items::Show failed to build input/
        ) do |error|
          expect(error.message).to include("CommandTower::Clients::ContractFixtureProvider::Items::ShowInput")
          expect(error.cause).to be_a(ArgumentError)
        end
      end
    end

    context "when required input attributes are missing" do
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::Show.new(client: client) }

      subject(:invoke) { endpoint.call }

      it "raises ConfigurationError with the construction cause" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /failed to build input/
        ) do |error|
          expect(error.cause).to be_a(ArgumentError)
        end
      end
    end

    context "when required declarations are missing" do
      subject(:invoke) { endpoint.call }

      let(:endpoint) do
        CommandTower::Clients::DiscoveryFixtureProvider::CatalogAsClass::Fetch.new(
          client: CommandTower::Clients::DiscoveryFixtureProvider.new(transport: transport)
        )
      end

      it "raises ConfigurationError listing the missing declarations" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /missing endpoint declarations/
        )
      end
    end

    context "when the serializer returns a Hash instead of SerializedRequest" do
      subject(:invoke) { endpoint.call }

      let(:endpoint) do
        CommandTower::Clients::ContractFixtureProvider::Items::BadSerializerReturn.new(client: client)
      end

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /must return CommandTower::Clients::SerializedRequest/
        )
      end
    end

    context "when the deserializer returns a Hash" do
      subject(:invoke) { endpoint.call }

      let(:endpoint) do
        CommandTower::Clients::ContractFixtureProvider::Items::BadDeserializerHashReturn.new(client: client)
      end

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /must not return a Hash/
        )
      end
    end

    context "when the deserializer returns a top-level Array" do
      subject(:result) { endpoint.call }

      let(:endpoint) do
        CommandTower::Clients::ContractFixtureProvider::Items::ArrayReturningEndpoint.new(client: client)
      end

      it "accepts Array as a valid top-level output" do
        expect(result).to be_success
        expect(result.output).to eq([])
      end
    end

    context "when the deserializer returns Transport::Response" do
      subject(:invoke) { endpoint.call }

      let(:endpoint) do
        CommandTower::Clients::ContractFixtureProvider::Items::BadDeserializerResponseReturn.new(client: client)
      end

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /must not return CommandTower::Clients::Transport::Response/
        )
      end
    end

    context "when upstream execution fails" do
      subject(:result) { endpoint.call }

      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 503, body: "unavailable", duration_ms: 2)
        end
      end
      let(:endpoint) { CommandTower::Clients::ContractFixtureProvider::Items::List.new(client: client) }

      it "returns the failed ClientResult unchanged without deserializing" do
        expect(result).to be_failure
        expect(result.error).to be_a(CommandTower::Clients::Errors::UpstreamError)
        expect(result.output).to be_a(CommandTower::Clients::Transport::Response)
        expect(result.metadata).to include(status: 503, duration_ms: 2)
      end
    end

    context "when the response body is malformed JSON" do
      subject(:result) { endpoint.call }

      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(
            status: 200,
            body: "{not-json",
            duration_ms: 3
          )
        end
      end
      let(:client) { CommandTower::Clients::SpecSupport::ReservationsGraphProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::SpecSupport::ReservationsGraph::List.new(client: client) }

      it "returns a failed ClientResult with DeserializationError and nil output" do
        expect(result).to be_failure
        expect(result.output).to be_nil
        expect(result.error).to be_a(CommandTower::Clients::Errors::DeserializationError)
        expect(result.error.details).to include(
          endpoint: "CommandTower::Clients::SpecSupport::ReservationsGraph::List",
          response_deserializer: "CommandTower::Clients::SpecSupport::ReservationsGraph::ListResponseDeserializer"
        )
        expect(result.error.cause).to be_a(JSON::ParserError)
        expect(result.metadata).to include(status: 200, duration_ms: 3)
        expect(result.metadata.values.join).not_to include("{not-json")
      end
    end

    context "with the recursive reservations graph" do
      subject(:result) { endpoint.call }

      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(
            status: 200,
            body: CommandTower::Clients::SpecSupport::ReservationsGraph::SAMPLE_PAYLOAD.to_json,
            duration_ms: 5
          )
        end
      end
      let(:client) { CommandTower::Clients::SpecSupport::ReservationsGraphProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::SpecSupport::ReservationsGraph::List.new(client: client) }
      let(:output) { result.output }
      let(:first_reservation) { output.reservations.first }
      let(:last_reservation) { output.reservations.last }

      it "returns one top-level ListOutput (wrapper remains valid; Array also allowed)" do
        expect(result).to be_success
        expect(output).to be_a(CommandTower::Clients::SpecSupport::ReservationsGraph::ListOutput)
        expect(result.metadata).to include(status: 200, duration_ms: 5)
        expect(result.provider_metadata).to eq({})
      end

      it "deserializes nested Reservation objects with nested Location objects" do
        expect(first_reservation).to be_a(CommandTower::Clients::SpecSupport::ReservationsGraph::Reservation)
        expect(first_reservation.external_id).to eq("r1")
        expect(first_reservation.location).to eq(
          CommandTower::Clients::SpecSupport::ReservationsGraph::Location.new(
            external_id: "loc1",
            name: "Castro"
          )
        )
      end

      it "deserializes nested arrays of Instructor and Spot objects" do
        expect(first_reservation.instructors).to contain_exactly(
          CommandTower::Clients::SpecSupport::ReservationsGraph::Instructor.new(
            external_id: "i1", name: "Alex"
          ),
          CommandTower::Clients::SpecSupport::ReservationsGraph::Instructor.new(
            external_id: "i2", name: "Blake"
          )
        )
        expect(first_reservation.spots).to contain_exactly(
          CommandTower::Clients::SpecSupport::ReservationsGraph::Spot.new(external_id: "s1", label: "DF12"),
          CommandTower::Clients::SpecSupport::ReservationsGraph::Spot.new(external_id: "s2", label: "T3")
        )
      end

      it "supports optional nil nested objects and empty nested arrays" do
        expect(last_reservation.location).to be_nil
        expect(last_reservation.instructors).to eq([])
        expect(last_reservation.spots).to eq([])
        expect(last_reservation.optional_note).to be_nil
      end

      it "deserializes pagination as a nested output object" do
        expect(output.pagination).to eq(
          CommandTower::Clients::SpecSupport::ReservationsGraph::Pagination.new(page: 1, pages: 3, count: 40)
        )
      end

      it "exposes no raw Hashes in the nested output graph" do
        expect(first_reservation.location).not_to be_a(Hash)
        expect(first_reservation.instructors).not_to include(a_kind_of(Hash))
        expect(first_reservation.spots).not_to include(a_kind_of(Hash))
        expect(output.pagination).not_to be_a(Hash)
        expect(output.reservations).not_to include(a_kind_of(Hash))
      end
    end

    context "when a required nested field is missing" do
      subject(:result) { endpoint.call }

      let(:payload) do
        {
          "results" => [
            {
              "id" => "r1",
              "location" => { "id" => "loc1" },
              "instructors" => [],
              "spots" => []
            }
          ],
          "meta" => { "pagination" => { "page" => 1, "pages" => 1, "count" => 1 } }
        }
      end
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: payload.to_json, duration_ms: 1)
        end
      end
      let(:client) { CommandTower::Clients::SpecSupport::ReservationsGraphProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::SpecSupport::ReservationsGraph::List.new(client: client) }

      it "returns a failed ClientResult wrapping KeyError as DeserializationError" do
        expect(result).to be_failure
        expect(result.output).to be_nil
        expect(result.error).to be_a(CommandTower::Clients::Errors::DeserializationError)
        expect(result.error.cause).to be_a(KeyError)
        expect(result.error.message).to include("CommandTower::Clients::SpecSupport::ReservationsGraph::List")
      end
    end

    context "when a nested object payload is the wrong type" do
      subject(:result) { endpoint.call }

      let(:payload) do
        {
          "results" => [
            {
              "id" => "r1",
              "location" => "not-an-object",
              "instructors" => [],
              "spots" => []
            }
          ],
          "meta" => { "pagination" => { "page" => 1, "pages" => 1, "count" => 1 } }
        }
      end
      let(:transport) do
        CommandTower::Clients::SpecSupport::FakeTransport.new do |_req|
          CommandTower::Clients::Transport::Response.build(status: 200, body: payload.to_json, duration_ms: 1)
        end
      end
      let(:client) { CommandTower::Clients::SpecSupport::ReservationsGraphProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::SpecSupport::ReservationsGraph::List.new(client: client) }

      it "returns a failed ClientResult for the nested TypeError/KeyError" do
        expect(result).to be_failure
        expect(result.output).to be_nil
        expect(result.error).to be_a(CommandTower::Clients::Errors::DeserializationError)
      end
    end

    context "when authentication is required by default" do
      subject(:result) { endpoint.call }

      let(:client) { CommandTower::Clients::AuthTrackingFixtureProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::AuthTrackingFixtureProvider::Items::RequiredAuth.new(client: client) }

      it "asks the client to enforce authentication before HTTP" do
        expect(result).to be_success
        expect(client.enforce_calls).to eq(1)
        expect(transport.calls.size).to eq(1)
      end
    end

    context "when authentication is :none" do
      subject(:result) { endpoint.call }

      let(:client) { CommandTower::Clients::AuthTrackingFixtureProvider.new(transport: transport) }
      let(:endpoint) { CommandTower::Clients::AuthTrackingFixtureProvider::Items::PublicAuth.new(client: client) }

      it "skips client enforcement and still executes" do
        expect(result).to be_success
        expect(client.enforce_calls).to eq(0)
        expect(transport.calls.size).to eq(1)
      end
    end
  end
end
