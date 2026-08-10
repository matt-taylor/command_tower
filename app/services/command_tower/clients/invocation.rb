# frozen_string_literal: true

module CommandTower
  module Clients
    # Product invocation boundary mixin.
    # Host: `module Clients; extend CommandTower::Clients::Invocation; end`
    # then `Clients.mariana_tek(user:)` / `Clients.mariana_tek(access_token:)`.
    # Provider resolution uses the extending module as the provider root (+self+).
    module Invocation
      def method_missing(name, *args, **scope, &block)
        return super if block || args.any?

        ScopedClient.new(provider: provider_for!(name), **scope)
      rescue Errors::DiscoveryError
        super
      end

      def respond_to_missing?(name, include_private = false)
        ClientBase.resolve_provider!(name, root: self)
        true
      rescue Errors::DiscoveryError
        super
      end

      def provider_for!(name)
        const_name = ConstResolution.normalize_name(name)

        providers_mutex.synchronize do
          providers[const_name] ||= ClientBase.resolve_provider!(name, root: self).new
        end
      end

      # Test helper — clears memoized providers (and their transport pools).
      def reset_providers!
        providers_mutex.synchronize do
          providers.clear
        end
      end

      # Test helper — seed a provider instance under a normalized name.
      def seed_provider!(name, provider)
        const_name = ConstResolution.normalize_name(name)
        providers_mutex.synchronize do
          providers[const_name] = provider
        end
      end

      private

      def providers_mutex
        @providers_mutex ||= Mutex.new
      end

      def providers
        @providers ||= {}
      end
    end

    extend Invocation
  end
end
