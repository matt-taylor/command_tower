# frozen_string_literal: true

module CommandTower
  module Clients
    # Internal constant helpers for provider/namespace/endpoint resolution.
    # Not a public product API — used by ClientBase / NamespaceProxy and tests.
    module ConstResolution
      module_function

      def normalize_name(name)
        raw = name.to_s.strip
        if raw.empty?
          raise Errors::DiscoveryError, "discovery name must be present"
        end

        raw.camelize
      end

      def const_get!(parent, name, expected:)
        const_name = normalize_name(name)
        path = "#{parent.name}::#{const_name}"

        begin
          parent.const_get(const_name, false)
        rescue NameError
          raise Errors::DiscoveryError,
                "missing #{expected}: expected #{path}"
        end
      end
    end
  end
end
