# frozen_string_literal: true

module CommandTower
  module Messaging
    class MessageDefinition
      # Base class for a definition's metadata schema. Hosts subclass it with
      # `attribute` and ActiveModel validations:
      #
      #   class Metadata < CommandTower::Messaging::MessageDefinition::Metadata
      #     attribute :class_name, :string
      #     validates :class_name, presence: true
      #   end
      #
      # Metadata arrives as a string-keyed Hash. `schema_errors` returns attribute names only,
      # never values, so callers can log them safely.
      class Metadata
        include ActiveModel::API
        include ActiveModel::Attributes

        # Builds an instance from a Hash. Keys the schema does not declare are ignored, so a
        # newer producer does not break an older schema.
        def self.from_hash(hash)
          source = (hash || {}).to_h.transform_keys(&:to_s)
          new(source.slice(*attribute_names))
        end

        # @return [Array<String>] names of attributes that fail validation (no values)
        def self.schema_errors(hash)
          instance = from_hash(hash)
          instance.valid? ? [] : instance.errors.attribute_names.map(&:to_s).uniq
        end
      end
    end
  end
end
