# frozen_string_literal: true

module CommandTower
  module Clients
    # Internal handoff from provider decode_response → EndpointBase resource deserializer.
    # Not a public product wrapper; not placed on ClientResult#output.
    class DecodedResponse
      attr_reader :payload, :provider_metadata

      def initialize(payload:, provider_metadata: {})
        @payload = payload
        @provider_metadata = provider_metadata
      end
    end
  end
end
