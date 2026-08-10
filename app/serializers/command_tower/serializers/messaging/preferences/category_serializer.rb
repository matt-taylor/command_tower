# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Preferences
        class CategorySerializer
          def self.serialize(category)
            {
              key: category.key,
              label: category.label,
              description: category.description,
              order: category.order,
              notifications: category.notifications.map { |notification|
                NotificationSerializer.serialize(notification)
              },
            }
          end
        end
      end
    end
  end
end
