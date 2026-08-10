# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Clients
      # Path composition for nested / indexed DeserializationError details.
      module Errors
        module_function

        def prefix(error, segment)
          unless error.is_a?(::CommandTower::Clients::Errors::DeserializationError)
            raise ::CommandTower::Clients::Errors::ConfigurationError,
                  "Errors.prefix expects CommandTower::Clients::Errors::DeserializationError"
          end

          details = error.details.is_a?(Hash) ? error.details.dup : {}
          details[:path] = compose_path(details[:path], segment)

          ::CommandTower::Clients::Errors::DeserializationError.new(
            message: error.message,
            details: details,
            cause: error.cause || error
          )
        end

        def compose_path(current, segment)
          current = current.to_s
          segment = segment.to_s

          return segment if current.empty?
          return current if segment.empty?

          if segment.start_with?("[")
            "#{segment}.#{current}"
          elsif current.start_with?("[")
            "#{segment}#{current}"
          else
            "#{segment}.#{current}"
          end
        end
        module_function :compose_path
      end
    end
  end
end
