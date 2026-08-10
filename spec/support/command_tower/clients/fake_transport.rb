# frozen_string_literal: true

module CommandTower
  module Clients
    module SpecSupport
      class FakeTransport
        attr_reader :calls

        def initialize(&handler)
          @handler = handler || ->(_request) {
            Transport::Response.build(status: 200, body: "", duration_ms: 1)
          }
          @calls = []
        end

        def call(request)
          @calls << request
          @handler.call(request)
        end
      end
    end
  end
end
