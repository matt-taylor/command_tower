# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Preferences
        class CatalogSerializer
          def self.serialize(catalog)
            {
              categories: catalog.categories.map { |category| CategorySerializer.serialize(category) },
            }
          end
        end
      end
    end
  end
end
