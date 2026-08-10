# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      CatalogResult = Data.define(:categories) do
        def self.build(categories:)
          new(categories: Array(categories).freeze).freeze
        end
      end
    end
  end
end
