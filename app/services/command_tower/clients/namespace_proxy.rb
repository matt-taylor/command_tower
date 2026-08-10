# frozen_string_literal: true

module CommandTower
  module Clients
    # Lightweight handle for a Zeitwerk namespace module under a provider.
    # Internal resolution primitive — not the locked product invocation API.
    class NamespaceProxy
      attr_reader :client, :namespace_module

      def initialize(client:, namespace_module:)
        raise Errors::ConfigurationError, "client is required" if client.nil?
        raise Errors::ConfigurationError, "namespace_module is required" if namespace_module.nil?

        @client = client
        @namespace_module = namespace_module
        @endpoint_mutex = Mutex.new
        @endpoints = {}
        @endpoint_classes = {}
      end

      # Resolve and memoize an EndpointBase instance bound to this proxy's client.
      # Prefer #build_endpoint for ScopedClient so user-bound instances are not shared.
      def resolve_endpoint!(name)
        const_name = ConstResolution.normalize_name(name)

        @endpoint_mutex.synchronize do
          @endpoints[const_name] ||= build_endpoint_instance!(
            resolve_endpoint_class_locked!(const_name),
            client: client
          )
        end
      end

      # Memoize endpoint class resolution only; always return a fresh instance.
      def build_endpoint(name, client:)
        klass = resolve_endpoint_class!(name)
        build_endpoint_instance!(klass, client: client)
      end

      def resolve_endpoint_class!(name)
        const_name = ConstResolution.normalize_name(name)

        @endpoint_mutex.synchronize do
          resolve_endpoint_class_locked!(const_name)
        end
      end

      private

      def resolve_endpoint_class_locked!(const_name)
        @endpoint_classes[const_name] ||= fetch_endpoint_class!(const_name)
      end

      def fetch_endpoint_class!(const_name)
        path = "#{namespace_module.name}::#{const_name}"
        klass = ConstResolution.const_get!(
          namespace_module,
          const_name,
          expected: "endpoint"
        )

        unless klass.is_a?(Class) && klass < EndpointBase
          raise Errors::DiscoveryError,
                  "invalid endpoint inheritance: expected #{path} < #{EndpointBase.name}"
        end

        klass
      end

      def build_endpoint_instance!(klass, client:)
        klass.new(client: client)
      end
    end
  end
end
