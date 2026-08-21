# frozen_string_literal: true

require "singleton"

module CommandTower
  module Deserializers
    module Clients
      # Composable type processors for response Result validation.
      # Each raises CommandTower::Clients::Errors::DeserializationError intentionally — no broad rescue.
      module Types
        module_function

        def integer
          IntegerType.instance
        end

        def string
          StringType.instance
        end

        def boolean
          BooleanType.instance
        end

        def float
          FloatType.instance
        end

        def array(element_type)
          ArrayType.new(normalize(element_type))
        end

        def union(*member_types)
          raise ::CommandTower::Clients::Errors::ConfigurationError, "Types.union requires at least one member" if member_types.empty?

          UnionType.new(member_types.map { |t| normalize(t) })
        end

        def normalize(type)
          case type
          when Type
            type
          when Class
            unless type < Result
              raise ::CommandTower::Clients::Errors::ConfigurationError,
                    "nested type must be a CommandTower::Deserializers::Clients::Result subclass (got: #{type})"
            end

            ResultInstanceType.new(type)
          when nil
            raise ::CommandTower::Clients::Errors::ConfigurationError, "type must not be nil"
          else
            raise ::CommandTower::Clients::Errors::ConfigurationError,
                  "unknown type declaration: #{type.inspect}"
          end
        end
        module_function :normalize

        class Type
          def call(_value, path:)
            raise NotImplementedError
          end

          def expected_label
            self.class.name
          end

          private

          def reject!(path, value, expected, message)
            raise ::CommandTower::Clients::Errors::DeserializationError.new(
              message: message,
              details: {
                path: path.to_s,
                expected: expected,
                actual: value.nil? ? "NilClass" : value.class.name,
                rule: "type",
                messages: [ message ]
              }
            )
          end
        end

        class IntegerType < Type
          include Singleton

          def call(value, path:)
            return value if value.is_a?(Integer)

            if value.is_a?(String)
              begin
                return Integer(value, 10)
              rescue ArgumentError
                reject!(path, value, "integer", "not a whole-number string")
              end
            end

            reject!(path, value, "integer", "expected Integer")
          end

          def expected_label
            "integer"
          end
        end

        class StringType < Type
          include Singleton

          def call(value, path:)
            return value if value.is_a?(String)

            reject!(path, value, "string", "expected String")
          end

          def expected_label
            "string"
          end
        end

        class BooleanType < Type
          include Singleton

          def call(value, path:)
            return value if value == true || value == false

            reject!(path, value, "boolean", "expected true or false")
          end

          def expected_label
            "boolean"
          end
        end

        class FloatType < Type
          include Singleton

          def call(value, path:)
            return value if value.is_a?(Float)
            return value.to_f if value.is_a?(Integer)

            if value.is_a?(String)
              begin
                return Float(value)
              rescue ArgumentError
                reject!(path, value, "float", "not a numeric string")
              end
            end

            reject!(path, value, "float", "expected Float")
          end

          def expected_label
            "float"
          end
        end

        class ResultInstanceType < Type
          def initialize(klass)
            @klass = klass
          end

          def call(value, path:)
            return value if value.instance_of?(@klass)

            reject!(path, value, @klass.name, "expected #{@klass.name} instance")
          end

          def expected_label
            @klass.name
          end
        end

        class ArrayType < Type
          def initialize(element_type)
            @element_type = element_type
          end

          def call(value, path:)
            unless value.is_a?(Array)
              reject!(path, value, "array", "expected Array")
            end

            value.each_with_index.map do |item, index|
              member_path = path.empty? ? "[#{index}]" : "#{path}[#{index}]"
              @element_type.call(item, path: member_path)
            end
          end

          def expected_label
            "array"
          end
        end

        class UnionType < Type
          def initialize(member_types)
            @member_types = member_types
          end

          def call(value, path:)
            @member_types.each do |member|
              begin
                return member.call(value, path: path)
              rescue ::CommandTower::Clients::Errors::DeserializationError
                next
              end
            end

            labels = @member_types.map(&:expected_label).join(" | ")
            reject!(path, value, labels, "value matched no union member")
          end

          def expected_label
            @member_types.map(&:expected_label).join(" | ")
          end
        end
      end
    end
  end
end
