# frozen_string_literal: true

# Test-only Zeitwerk-shaped constants for discovery + contract specs.
# Not production MarianaTek.
module CommandTower
  module Clients
    class DiscoveryFixtureProvider < ClientBase
      protected

      def base_url
        "https://example.test"
      end

      module Catalog
        FetchInput = Data.define
        FetchOutput = Data.define(:ok)

        class FetchRequestSerializer
          def self.call(_input)
            SerializedRequest.build
          end
        end

        class FetchResponseDeserializer
          def self.call(_response)
            FetchOutput.new(ok: true)
          end
        end

        class Fetch < EndpointBase
          http_method :get
          path "/items/1"
          input FetchInput
          request_serializer FetchRequestSerializer
          response_deserializer FetchResponseDeserializer
        end

        class PlainObject
        end
      end

      class CatalogAsClass
        class Fetch < EndpointBase
        end
      end
    end

    class DiscoveryFixturePlain
    end

    # Contract fixtures for Phase 1.3.3–1.3.4 endpoint declaration / lifecycle specs.
    class ContractFixtureProvider < ClientBase
      protected

      def base_url
        "https://example.test/api/v1"
      end

      module Items
        ShowInput = Data.define(:id)
        ShowOutput = Data.define(:id)

        class ShowRequestSerializer
          def self.call(_input)
            SerializedRequest.build(
              query: { "expand" => "true" },
              headers: { "X-Fixture" => "show" },
              body: nil
            )
          end
        end

        class ShowResponseDeserializer
          def self.call(_response)
            ShowOutput.new(id: "deserialized")
          end
        end

        class Show < EndpointBase
          http_method :get
          path { |input| "/items/#{input.id}" }
          input ShowInput
          request_serializer ShowRequestSerializer
          response_deserializer ShowResponseDeserializer
        end

        ListInput = Data.define
        ListOutput = Data.define(:items)

        class ListRequestSerializer
          def self.call(_input)
            SerializedRequest.build(query: { "page" => "1" })
          end
        end

        class ListResponseDeserializer
          def self.call(_response)
            ListOutput.new(items: [])
          end
        end

        class List < EndpointBase
          http_method :get
          path "/items"
          input ListInput
          request_serializer ListRequestSerializer
          response_deserializer ListResponseDeserializer
        end

        CreateInput = Data.define(:name)
        CreateOutput = Data.define(:name)

        class CreateRequestSerializer
          def self.call(input)
            SerializedRequest.build(body: { name: input.name })
          end
        end

        class CreateResponseDeserializer
          def self.call(_response)
            CreateOutput.new(name: "created")
          end
        end

        class Create < EndpointBase
          http_method :post
          path "/items"
          input CreateInput
          request_serializer CreateRequestSerializer
          response_deserializer CreateResponseDeserializer
        end

        EmptyInput = Data.define
        EmptyOutput = Data.define(:ok)

        class EmptyRequestSerializer
          def self.call(_input)
            SerializedRequest.build
          end
        end

        class EmptyResponseDeserializer
          def self.call(_response)
            EmptyOutput.new(ok: true)
          end
        end

        class HashReturningSerializer
          def self.call(_input)
            { query: {}, body: nil, headers: {} }
          end
        end

        class BadSerializerReturn < EndpointBase
          http_method :get
          path "/x"
          input EmptyInput
          request_serializer HashReturningSerializer
          response_deserializer EmptyResponseDeserializer
        end

        class HashReturningResponseDeserializer
          def self.call(_response)
            { "id" => 1 }
          end
        end

        class BadDeserializerHashReturn < EndpointBase
          http_method :get
          path "/bad-hash"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer HashReturningResponseDeserializer
        end

        class ArrayReturningResponseDeserializer
          def self.call(_payload)
            []
          end
        end

        # Valid top-level Array output (Phase 1.4.1b allows collections at the top level).
        class ArrayReturningEndpoint < EndpointBase
          http_method :get
          path "/ok-array"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer ArrayReturningResponseDeserializer
        end

        class BadDeserializerArrayReturn < ArrayReturningEndpoint
        end

        class ResponseReturningDeserializer
          def self.call(_payload)
            Clients::Transport::Response.build(status: 200, body: "{}")
          end
        end

        class BadDeserializerResponseReturn < EndpointBase
          http_method :get
          path "/bad-response"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer ResponseReturningDeserializer
        end

        class PublicPing < EndpointBase
          authentication :none
          http_method :get
          path "/public"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer EmptyResponseDeserializer
        end
      end
    end

    class AbsoluteOnlyFixtureProvider < ClientBase
      # No base_url — absolute request URLs must still work.
    end

    class AuthTrackingFixtureProvider < ClientBase
      attr_reader :enforce_calls

      def initialize(transport:)
        super(transport: transport)
        @enforce_calls = 0
      end

      def enforce_authentication!
        @enforce_calls += 1
      end

      protected

      def base_url
        "https://example.test"
      end

      module Items
        EmptyInput = Data.define
        EmptyOutput = Data.define(:ok)

        class EmptyRequestSerializer
          def self.call(_input)
            SerializedRequest.build
          end
        end

        class EmptyResponseDeserializer
          def self.call(_response)
            EmptyOutput.new(ok: true)
          end
        end

        class RequiredAuth < EndpointBase
          http_method :get
          path "/required"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer EmptyResponseDeserializer
        end

        class PublicAuth < EndpointBase
          authentication :none
          http_method :get
          path "/public"
          input EmptyInput
          request_serializer EmptyRequestSerializer
          response_deserializer EmptyResponseDeserializer
        end
      end
    end
  end
end
