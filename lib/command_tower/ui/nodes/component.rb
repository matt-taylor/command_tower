# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Registered native component with a required `fallback` tree. A document
      # holds at most one `component` (enforced by Document).
      class Component < Node
        TYPE = "component"
        KEY_FORMAT = /\A[a-z0-9_]+(?:\.[a-z0-9_]+)*\z/
        VARIANT_FORMAT = /\A[a-z0-9_]+\z/

        field :key, :string
        field :variant, :string
        field :data, default: -> { {} }
        field :fallback

        validates :key, format: { with: KEY_FORMAT }
        validates :variant, format: { with: VARIANT_FORMAT }, allow_nil: true
        validate :data_is_hash
        validate :fallback_is_node

        def each_child
          yield "fallback", fallback if fallback.is_a?(Node)
        end

        private

        def data_is_hash
          errors.add(:data, :invalid) unless data.is_a?(Hash)
        end

        def fallback_is_node
          errors.add(:fallback, :invalid_child) unless fallback.is_a?(Node)
        end
      end
    end
  end
end
