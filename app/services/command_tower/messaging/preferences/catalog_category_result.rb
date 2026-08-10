# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      CatalogCategoryResult = Data.define(:key, :label, :description, :order, :notifications) do
        def self.build(key:, label:, description:, order:, notifications:)
          new(
            key: key.to_s,
            label: label.to_s,
            description:,
            order: Integer(order),
            notifications: Array(notifications).freeze,
          ).freeze
        end
      end
    end
  end
end
