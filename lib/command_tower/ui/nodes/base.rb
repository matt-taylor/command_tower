# frozen_string_literal: true

require "active_model"

module CommandTower
  module UI
    module Nodes
      ICON_FORMAT = /\A[a-z0-9][a-z0-9_-]{0,63}\z/

      # Shared machinery for every wire object: node classes, spans, actions and
      # key_value items. ActiveModel attributes and validations; `as_json` emits
      # camelCase keys with snake_case token values.
      #
      # Validation errors are read through `errors` types only (symbols such as
      # :inclusion). Never interpolate a value into a message: values can be
      # sensitive (`code`) or PII. `inspect` and `to_s` therefore show the class
      # name only.
      class Base
        include ActiveModel::Model
        include ActiveModel::Attributes

        class_attribute :wire_fields, instance_writer: false, default: []

        class << self
          # Declares an attribute that appears on the wire (nil values are omitted).
          def field(name, type = nil, **)
            attribute(name, type, **)
            self.wire_fields += [name]
          end
        end

        validate :wire_strings_within_limit

        def node?
          false
        end

        def wire_type
          nil
        end

        # Yields [relative_path, object] for each nested wire object, in document order.
        def each_child; end

        def as_json(_options = nil)
          json = {}
          json["type"] = wire_type if wire_type
          self.class.wire_fields.each do |name|
            value = public_send(name)
            json[name.to_s.camelize(:lower)] = serialize(value) unless value.nil?
          end
          json
        end

        def inspect
          "#<#{self.class.name}>"
        end

        def to_s
          inspect
        end

        def pretty_print(printer)
          printer.text(inspect)
        end

        private

        def serialize(value)
          case value
          when Array then value.map { |item| serialize(item) }
          else value.as_json
          end
        end

        def wire_strings_within_limit
          self.class.wire_fields.each do |name|
            value = public_send(name)
            next unless value.is_a?(String) && value.length > Limits::MAX_STRING_LENGTH

            errors.add(name, :too_long, count: Limits::MAX_STRING_LENGTH)
          end
        end

        def nested_objects(name, list)
          return unless list.is_a?(Array)

          list.each_with_index do |item, index|
            yield "#{name}[#{index}]", item if item.is_a?(Base)
          end
        end
      end

      # A catalog primitive (counts toward the document node and depth limits).
      class Node < Base
        def node?
          true
        end

        def wire_type
          self.class::TYPE
        end
      end

      # Node with `children` (stack, card, facts).
      class Container < Node
        field :children, default: -> { [] }

        validate :children_are_nodes

        def each_child(&)
          nested_objects("children", children, &)
        end

        private

        def children_are_nodes
          return if children.is_a?(Array) && children.all?(Node)

          errors.add(:children, :invalid_child)
        end
      end
    end
  end
end
