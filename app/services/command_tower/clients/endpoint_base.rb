# frozen_string_literal: true

module CommandTower
  module Clients
    class EndpointBase
      AUTHENTICATION_MODES = %i[required none].freeze

      class << self
        attr_reader :declared_http_method, :declared_path, :declared_input_class,
                    :declared_request_serializer, :declared_response_deserializer,
                    :declared_authentication

        def http_method(method)
          @declared_http_method = Transport::Request.validate_method!(method)
        end

        def path(value = nil, &block)
          if block && !value.nil?
            raise Errors::ConfigurationError,
                  "#{name} path must be a String or a block, not both"
          end

          @declared_path = block || value
        end

        def input(klass)
          unless klass.is_a?(Class)
            raise Errors::ConfigurationError,
                  "#{name} input must be a Class (got: #{klass.inspect})"
          end

          @declared_input_class = klass
        end

        def request_serializer(serializer)
          unless serializer.respond_to?(:call)
            raise Errors::ConfigurationError,
                  "#{name} request_serializer must respond to call " \
                  "(got: #{serializer.inspect})"
          end

          @declared_request_serializer = serializer
        end

        def response_deserializer(deserializer)
          unless deserializer.respond_to?(:call)
            raise Errors::ConfigurationError,
                  "#{name} response_deserializer must respond to call " \
                  "(got: #{deserializer.inspect})"
          end

          @declared_response_deserializer = deserializer
        end

        # Default when omitted: :required. Public endpoints must opt out with :none.
        def authentication(mode)
          normalized = mode.to_sym
          unless AUTHENTICATION_MODES.include?(normalized)
            raise Errors::ConfigurationError,
                  "#{name} authentication must be one of " \
                  "#{AUTHENTICATION_MODES.join(', ')} (got: #{mode.inspect})"
          end

          @declared_authentication = normalized
        end

        def authentication_mode
          declared_authentication || :required
        end
      end

      attr_reader :client

      def initialize(client:)
        raise Errors::ConfigurationError, "client is required" if client.nil?

        @client = client
      end

      # Internal orchestration — not the locked product invocation API.
      # Builds input, serializes, executes, then deserializes a successful response
      # into a top-level provider contract object or Array of contracts.
      def call(**attributes)
        assert_declarations!
        enforce_authentication_if_required!
        input = build_input!(attributes)
        path = resolve_path(input)
        serialized = serialize_request!(input)

        request = Transport::Request.build(
          method: self.class.declared_http_method,
          url: path,
          query: serialized.query,
          body: serialized.body,
          headers: serialized.headers
        )

        result = client.execute(request)
        return result if result.failure?

        deserialize_success!(result)
      end

      private

      def enforce_authentication_if_required!
        return if self.class.authentication_mode == :none

        client.enforce_authentication!
      end

      def assert_declarations!
        missing = []
        missing << "http_method" if self.class.declared_http_method.nil?
        missing << "path" if self.class.declared_path.nil?
        missing << "input" if self.class.declared_input_class.nil?
        missing << "request_serializer" if self.class.declared_request_serializer.nil?
        missing << "response_deserializer" if self.class.declared_response_deserializer.nil?

        return if missing.empty?

        raise Errors::ConfigurationError,
              "#{self.class.name} is missing endpoint declarations: #{missing.join(', ')}"
      end

      def build_input!(attributes)
        self.class.declared_input_class.new(**attributes)
      rescue ArgumentError => e
        raise Errors::ConfigurationError,
              "#{self.class.name} failed to build input " \
              "#{self.class.declared_input_class.name}: #{e.message}",
              cause: e
      end

      def resolve_path(input)
        declared = self.class.declared_path
        path = if declared.respond_to?(:call)
                 declared.call(input)
        else
                 declared
        end

        path = path.to_s
        if path.strip.empty?
          raise Errors::ConfigurationError,
                "#{self.class.name} resolved path must be present"
        end

        path
      end

      def serialize_request!(input)
        serializer = self.class.declared_request_serializer
        unless serializer.respond_to?(:call)
          raise Errors::ConfigurationError,
                "#{self.class.name} request_serializer must respond to call"
        end

        serialized = serializer.call(input)
        return serialized if serialized.is_a?(SerializedRequest)

        raise Errors::ConfigurationError,
              "#{self.class.name} request_serializer must return " \
              "#{SerializedRequest.name} (got: #{serialized.class.name})"
      end

      def deserialize_success!(result)
        deserializer = self.class.declared_response_deserializer
        unless deserializer.respond_to?(:call)
          raise Errors::ConfigurationError,
                "#{self.class.name} response_deserializer must respond to call"
        end

        decoded = nil
        begin
          decoded = client.decode_response(result.output)
          output = deserializer.call(decoded.payload)
          validate_top_level_output!(output)

          ClientResult.success(
            output: output,
            metadata: result.metadata,
            provider_metadata: decoded.provider_metadata
          )
        rescue Errors::DeserializationError, JSON::ParserError, KeyError, TypeError => e
          ClientResult.failure(
            error: wrap_deserialization_error(e, deserializer),
            output: nil,
            metadata: result.metadata,
            provider_metadata: decoded&.provider_metadata || {}
          )
        end
      end

      def validate_top_level_output!(output)
        if output.nil?
          raise Errors::ConfigurationError,
                "#{self.class.name} response_deserializer must not return nil"
        end

        if output.is_a?(Hash)
          raise Errors::ConfigurationError,
                "#{self.class.name} response_deserializer must not return a Hash"
        end

        return unless output.is_a?(Transport::Response)

        raise Errors::ConfigurationError,
              "#{self.class.name} response_deserializer must not return " \
              "#{Transport::Response.name}"
      end

      def wrap_deserialization_error(error, deserializer)
        if error.is_a?(Errors::DeserializationError) &&
           error.details.is_a?(Hash) &&
           error.details[:endpoint].present?
          return error
        end

        details = {
          endpoint: self.class.name,
          response_deserializer: deserializer_name(deserializer)
        }

        if error.is_a?(Errors::DeserializationError) && error.details.is_a?(Hash)
          details = error.details.merge(details)
        end

        Errors::DeserializationError.new(
          message: "#{self.class.name} failed to deserialize response " \
                   "via #{deserializer_name(deserializer)}: #{error.message}",
          details: details,
          cause: error.is_a?(Errors::DeserializationError) ? error.cause || error : error
        )
      end

      def deserializer_name(deserializer)
        deserializer.respond_to?(:name) && deserializer.name.present? ? deserializer.name : deserializer.inspect
      end
    end
  end
end
