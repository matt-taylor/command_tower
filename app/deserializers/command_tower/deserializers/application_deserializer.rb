# frozen_string_literal: true

module CommandTower
  module Deserializers
    class ApplicationDeserializer
      class DeserializerResult
        attr_reader :input, :errors

        def initialize(success:, input: nil, errors: nil)
          @success = success
          @input = input
          @errors = errors
        end

        def success?
          @success
        end

        def failure?
          !success?
        end
      end

      def self.call(params)
        new.call(params)
      end

      def call(_params)
        raise NotImplementedError
      end

      protected

      def success(input)
        DeserializerResult.new(success: true, input: input)
      end

      def failure(errors:)
        # Do not use Array(hash) — Kernel#Array converts Hash to pairs.
        normalized =
          case errors
          when Array then errors
          when nil then []
          else [errors]
          end
        DeserializerResult.new(success: false, errors: normalized)
      end

      # Returns the coerced value, or a finished DeserializerResult failure.
      def unwrap(coercion)
        return failure(errors: coercion.failures) if coercion.failure?

        coercion.value
      end

      def deserializer_result?(value)
        value.is_a?(DeserializerResult)
      end

      def fetch_param(params, *keys)
        hash = normalize_params(params)
        keys.each do |key|
          string_key = key.to_s
          symbol_key = key.to_sym
          if hash.key?(string_key)
            return CoercionResult.ok(hash[string_key])
          end
          if hash.key?(symbol_key)
            return CoercionResult.ok(hash[symbol_key])
          end
        end
        CoercionResult.ok(nil)
      end

      def require_string(raw, code: "missing_required_fields", field: nil)
        if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
          return CoercionResult.fail(code: code, field: field)
        end
        unless raw.is_a?(String)
          return CoercionResult.fail(code: "invalid_field_types", field: field)
        end

        CoercionResult.ok(raw.strip)
      end

      def optional_string(raw, default: nil)
        return CoercionResult.ok(default) if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
        unless raw.is_a?(String)
          return CoercionResult.fail(code: "invalid_field_types")
        end

        CoercionResult.ok(raw.strip)
      end

      def coerce_integer(raw, code: "invalid_integer", field: nil)
        case raw
        when Integer
          CoercionResult.ok(raw)
        when String
          stripped = raw.strip
          return CoercionResult.fail(code: code, field: field) unless /\A-?\d+\z/.match?(stripped)

          CoercionResult.ok(Integer(stripped, 10))
        when nil
          CoercionResult.fail(code: code, field: field)
        else
          CoercionResult.fail(code: code, field: field)
        end
      end

      def require_integer(raw, code: "invalid_integer", field: nil, min: nil, max: nil)
        result = coerce_integer(raw, code: code, field: field)
        return result if result.failure?

        value = result.value
        if !min.nil? && value < min
          return CoercionResult.fail(code: code, field: field)
        end
        if !max.nil? && value > max
          return CoercionResult.fail(code: code, field: field)
        end

        CoercionResult.ok(value)
      end

      def one_of(raw, allowed:, code: "invalid_value", field: nil)
        value = raw.is_a?(String) ? raw.strip : raw
        unless allowed.include?(value)
          return CoercionResult.fail(code: code, field: field)
        end

        CoercionResult.ok(value)
      end

      private

      def normalize_params(params)
        if params.respond_to?(:to_unsafe_h)
          params.to_unsafe_h
        elsif params.respond_to?(:to_h)
          params.to_h
        else
          params
        end
      end
    end
  end
end
