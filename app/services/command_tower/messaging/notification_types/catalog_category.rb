# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      # Immutable grouped catalog entry returned by Registry#catalog.
      CatalogCategory = Data.define(:key, :label, :order, :declarations) do
        def self.build(key:, label:, order:, declarations:)
          new(
            key: key.to_s,
            label: label.to_s,
            order:,
            declarations: Array(declarations).freeze,
          ).freeze
        end
      end
    end
  end
end
