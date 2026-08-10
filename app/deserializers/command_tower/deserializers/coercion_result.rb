# frozen_string_literal: true

module CommandTower
  module Deserializers
    class CoercionResult
      attr_reader :value, :failures

      def initialize(ok:, value: nil, failures: [])
        @ok = ok
        @value = value
        @failures = failures
      end

      def ok?
        @ok
      end

      def failure?
        !ok?
      end

      def self.ok(value)
        new(ok: true, value: value, failures: [])
      end

      def self.fail(code:, field: nil, details: {})
        new(
          ok: false,
          value: nil,
          failures: [Failure.build(code: code, field: field, details: details)]
        )
      end
    end
  end
end
