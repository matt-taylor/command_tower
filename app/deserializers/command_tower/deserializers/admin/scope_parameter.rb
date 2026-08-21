# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Admin
      module ScopeParameter
        module_function

        def extract(params, tool_id:)
          definition = CommandTower.config.registry.admin_workspace.fetch(tool_id)
          return nil unless definition.scope_required?

          keys = parameter_keys(definition.scope_parameter)
          raw = fetch_raw(params, keys)
          return nil if raw.nil? || raw.to_s.strip.empty?

          raw.to_s.strip
        end

        def fetch_raw(params, keys)
          hash =
            if params.respond_to?(:to_unsafe_h)
              params.to_unsafe_h
            elsif params.respond_to?(:to_h)
              params.to_h
            else
              params
            end

          keys.each do |key|
            string_key = key.to_s
            symbol_key = key.to_sym
            return hash[string_key] if hash.key?(string_key)
            return hash[symbol_key] if hash.key?(symbol_key)
          end
          nil
        end
        private_class_method :fetch_raw

        def parameter_keys(parameter)
          snake = parameter.to_s
          camel = snake.camelize(:lower)
          [snake.to_sym, snake, camel.to_sym, camel]
        end
        private_class_method :parameter_keys
      end
    end
  end
end
