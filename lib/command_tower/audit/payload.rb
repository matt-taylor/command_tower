# frozen_string_literal: true

require "json"

module CommandTower
  module Audit
    module Payload
      SCALAR_TYPES = [NilClass, TrueClass, FalseClass, Integer, Float, String, Symbol].freeze
      MAX_DEPTH = 4
      MAX_BYTES = 16_384
      CHANGE_KEYS = %w[from to].freeze

      module_function

      def validate!(value, depth: 0, path: "payload")
        if depth > MAX_DEPTH
          raise InvalidPayloadError, "#{path} exceeds max nesting depth #{MAX_DEPTH}"
        end

        case value
        when Hash
          value.each do |key, nested|
            unless key.is_a?(String) || key.is_a?(Symbol)
              raise InvalidPayloadError, "#{path} has a non-string key #{key.inspect}"
            end

            validate!(nested, depth: depth + 1, path: "#{path}.#{key}")
          end
        when Array
          value.each_with_index do |item, index|
            validate!(item, depth: depth + 1, path: "#{path}[#{index}]")
          end
        else
          unless SCALAR_TYPES.any? { |type| value.is_a?(type) }
            raise InvalidPayloadError, "#{path} contains unsafe type #{value.class}"
          end
        end

        value
      end

      def validate_changes!(changes, allowed_keys:)
        unless changes.nil? || changes.is_a?(Hash)
          raise InvalidPayloadError, "changes must be a Hash"
        end

        normalized = {}
        (changes || {}).each do |key, value|
          unless key.is_a?(String) || key.is_a?(Symbol)
            raise InvalidPayloadError, "changes has a non-string key #{key.inspect}"
          end

          token = key.to_s
          unless token.match?(CommandTower::Events::SEGMENT)
            raise InvalidPayloadError, "changes key #{key.inspect} is invalid"
          end

          unless allowed_keys.map(&:to_s).include?(token)
            raise ForbiddenChangeKeyError,
              "changes key #{token} is not allowed (allowed: #{allowed_keys.join(", ").presence || "none"})"
          end

          unless value.is_a?(Hash)
            raise InvalidPayloadError, "changes.#{token} must be a Hash with from/to"
          end

          extra = value.keys.map(&:to_s) - CHANGE_KEYS
          if extra.any? || (value.keys.map(&:to_s) & CHANGE_KEYS).empty?
            raise InvalidPayloadError, "changes.#{token} must use from/to keys only"
          end

          from_value = value.key?(:from) ? value[:from] : value["from"]
          to_value = value.key?(:to) ? value[:to] : value["to"]
          validate!(from_value, depth: 2, path: "changes.#{token}.from")
          validate!(to_value, depth: 2, path: "changes.#{token}.to")
          normalized[token] = { "from" => from_value, "to" => to_value }
        end

        enforce_size!(normalized)
        normalized
      end

      def validate_metadata!(metadata)
        unless metadata.nil? || metadata.is_a?(Hash)
          raise InvalidPayloadError, "metadata must be a Hash"
        end

        validated = metadata || {}
        validate!(validated, path: "metadata")
        enforce_size!(validated)
        stringify_keys(validated)
      end

      def enforce_size!(value)
        encoded = JSON.generate(jsonify(value))
        return if encoded.bytesize <= MAX_BYTES

        raise InvalidPayloadError, "audit payload exceeds #{MAX_BYTES} bytes"
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), memo|
            memo[key.to_s] = stringify_keys(nested)
          end
        when Array
          value.map { |item| stringify_keys(item) }
        else
          value
        end
      end

      def jsonify(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), memo| memo[key.to_s] = jsonify(nested) }
        when Array
          value.map { |item| jsonify(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end
    end
  end
end
