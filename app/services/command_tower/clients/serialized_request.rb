# frozen_string_literal: true

module CommandTower
  module Clients
    # Pure serializer output for endpoint request assembly.
    # Not a Hash — keeps the client framework on typed value objects.
    SerializedRequest = Data.define(:query, :body, :headers) do
      def self.build(query: {}, body: nil, headers: {})
        new(
          query: query.to_h,
          body: body,
          headers: headers.to_h
        )
      end
    end
  end
end
