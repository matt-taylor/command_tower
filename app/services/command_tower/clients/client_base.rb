# frozen_string_literal: true

module CommandTower
  module Clients
    class ClientBase
      class << self
        # Internal: resolve a provider class under +root+ via Zeitwerk const_get.
        # Host product entry extends Invocation so +root+ is the host Clients module.
        # Not the locked product invocation API.
        def resolve_provider!(name, root: Clients)
          const_name = ConstResolution.normalize_name(name)
          path = "#{root.name}::#{const_name}"
          klass = ConstResolution.const_get!(root, const_name, expected: "provider")

          unless klass.is_a?(Class) && klass < ClientBase
            raise Errors::DiscoveryError,
                  "invalid provider inheritance: expected #{path} < #{ClientBase.name}"
          end

          klass
        end
      end

      def initialize(transport: Transport::FaradayAdapter.new(config: Transport::FaradayConfig.from_env))
        raise Errors::ConfigurationError, "transport is required" if transport.nil?

        @transport = transport
        @namespace_mutex = Mutex.new
        @namespaces = {}
      end

      # Internal: resolve a namespace module under this provider and wrap NamespaceProxy.
      # Not the locked product invocation API.
      def resolve_namespace!(name)
        const_name = ConstResolution.normalize_name(name)

        @namespace_mutex.synchronize do
          @namespaces[const_name] ||= build_namespace_proxy!(const_name)
        end
      end

      # Primary execution contract.
      # Accepts a normalized Clients::Transport::Request.
      # Optional +context:+ is internal framework plumbing (typically ScopedClient).
      def execute(request, context: nil)
        validate_request!(request)

        prepared = prepare_request(request, context: context)
        started_at = monotonic_now

        response = call_transport(prepared, started_at)
        return response if response.is_a?(ClientResult)

        build_result(response, started_at)
      end

    # Provider-owned authentication check. Default is a no-op so bare/test
    # providers keep working; ScopedClient delegates opaque scope kwargs.
    def enforce_authentication!(**)
      nil
    end

      # Strip the transport wrapper before resource deserializers run.
      # Default payload is the raw body — providers own encoding (JSON, XML, …).
      def decode_response(response)
        DecodedResponse.new(
          payload: response.body,
          provider_metadata: {}
        )
      end

      protected

      # Provider host root (and optional path prefix). Required only when the
      # request URL is relative. Absolute request URLs are preserved as-is.
      def base_url
        nil
      end

      def default_headers
        {}
      end

      def apply_authentication(request, context: nil)
        request
      end

      def map_provider_error(response)
        Errors::UpstreamError.new(
          message: "Upstream request failed with status #{response.status}",
          details: { status: response.status }
        )
      end

      private

      def build_namespace_proxy!(const_name)
        path = "#{self.class.name}::#{const_name}"
        mod = ConstResolution.const_get!(self.class, const_name, expected: "namespace")

        unless mod.instance_of?(Module)
          raise Errors::DiscoveryError,
                "invalid namespace: expected #{path} to be a Module (Zeitwerk folder)"
        end

        NamespaceProxy.new(client: self, namespace_module: mod)
      end

      def validate_request!(request)
        return if request.is_a?(Transport::Request)

        raise Errors::ConfigurationError,
              "request must be a #{Transport::Request.name}"
      end

      def prepare_request(request, context: nil)
        with_defaults = Transport::Request.build(
          method: request.method,
          url: absolutize_url(request.url),
          headers: default_headers.merge(request.headers),
          body: request.body,
          query: request.query,
          timeout: request.timeout
        )
        apply_authentication(with_defaults, context: context)
      end

      def absolutize_url(url)
        return url.to_s if Url.absolute?(url)

        Url.join(base_url, url)
      end

      def call_transport(prepared, started_at)
        response = @transport.call(prepared)
        unless response.is_a?(Transport::Response)
          raise Errors::ConfigurationError,
                "transport must return a #{Transport::Response.name}"
        end
        response
      rescue Transport::Error => e
        ClientResult.failure(
          error: Errors::UpstreamError.new(message: e.message, cause: e),
          metadata: natural_metadata(status: nil, started_at: started_at, response: nil)
        )
      end

      def build_result(response, started_at)
        metadata = natural_metadata(
          status: response.status,
          started_at: started_at,
          response: response
        )

        if response.success?
          ClientResult.success(output: response, metadata: metadata)
        else
          ClientResult.failure(
            error: map_provider_error(response),
            output: response,
            metadata: metadata
          )
        end
      end

      def natural_metadata(status:, started_at:, response:)
        metadata = {}
        metadata[:status] = status unless status.nil?
        duration_ms = response&.duration_ms || elapsed_ms(started_at)
        metadata[:duration_ms] = duration_ms unless duration_ms.nil?
        metadata
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms(started_at)
        ((monotonic_now - started_at) * 1000).round
      end
    end
  end
end
