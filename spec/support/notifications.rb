# frozen_string_literal: true

module CommandTower
  module NotificationsSpecHelper
    def capture_notifications(pattern)
      recorded = []
      subscriber = ActiveSupport::Notifications.subscribe(pattern) do |name, _started, _finished, _id, payload|
        recorded << { name: name, payload: payload.dup }
      end
      [recorded, subscriber]
    end

    def unsubscribe_notifications(subscriber)
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::NotificationsSpecHelper
end
