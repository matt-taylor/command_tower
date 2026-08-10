# frozen_string_literal: true

module CommandTower
  module Clients
    module SpecSupport
      class FakeProviderClient < ClientBase
        def initialize(transport:, default_headers: {}, auth_header: nil)
          super(transport: transport)
          @override_default_headers = default_headers
          @auth_header = auth_header
        end

        protected

        def default_headers
          @override_default_headers
        end

        def apply_authentication(request, context: nil)
          return request if @auth_header.nil?

          request.merge_headers("Authorization" => @auth_header)
        end

        def map_provider_error(response)
          Errors::UpstreamError.new(
            message: "fake provider failed with #{response.status}",
            details: { status: response.status, provider: "fake" }
          )
        end
      end
    end
  end
end
