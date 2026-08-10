# frozen_string_literal: true

module CommandTower
  module Clients
    # Request-scoped handle around a memoized provider. Holds opaque scope kwargs
    # (e.g. user:, access_token:) without interpreting provider credentials.
    class ScopedClient
      attr_reader :provider, :scope

      def initialize(provider:, **scope)
        raise Errors::ConfigurationError, "provider is required" if provider.nil?

        @provider = provider
        @scope = scope.freeze
        @namespace_mutex = Mutex.new
        @namespaces = {}
      end

      def user
        scope[:user]
      end

      def [](key)
        scope[key]
      end

      def enforce_authentication!
        provider.enforce_authentication!(**scope)
      end

      def execute(request)
        provider.execute(request, context: self)
      end

      def decode_response(response)
        provider.decode_response(response)
      end

      def method_missing(name, *args, **kwargs, &block)
        return super if block || args.any? || !kwargs.empty?

        NamespaceHandle.new(
          scoped_client: self,
          namespace_proxy: resolve_namespace_proxy!(name)
        )
      rescue Errors::DiscoveryError
        super
      end

      def respond_to_missing?(name, include_private = false)
        resolve_namespace_proxy!(name)
        true
      rescue Errors::DiscoveryError
        super
      end

      # Fresh endpoint instances bound to this scoped client (not memoized).
      class NamespaceHandle
        def initialize(scoped_client:, namespace_proxy:)
          @scoped_client = scoped_client
          @namespace_proxy = namespace_proxy
        end

        def method_missing(name, *args, **attributes, &block)
          raise ArgumentError, "endpoint invocation does not take a block" if block
          raise ArgumentError, "endpoint invocation does not take positional args" if args.any?

          endpoint = @namespace_proxy.build_endpoint(name, client: @scoped_client)
          endpoint.call(**attributes)
        end

        def respond_to_missing?(_name, _include_private = false)
          true
        end
      end

      private

      def resolve_namespace_proxy!(name)
        const_name = ConstResolution.normalize_name(name)

        @namespace_mutex.synchronize do
          @namespaces[const_name] ||= provider.resolve_namespace!(name)
        end
      end
    end
  end
end
