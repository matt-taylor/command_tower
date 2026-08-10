# frozen_string_literal: true

require_relative "messaging_notification_types"
require_relative "messaging_preferences"

# Tag wiring for planner specs: notification registry reset + preference helpers.
# Call CommandTower::Messaging::Planner.plan directly in examples (no thin forwarder).
RSpec.configure do |config|
  config.include MessagingNotificationTypesHelper, :messaging_planner
  config.include MessagingPreferencesHelper, :messaging_planner

  config.around(:each, :messaging_planner) do |example|
    MessagingNotificationTypesHelper.reset_notification_type_registry!
    example.run
    MessagingNotificationTypesHelper.reset_notification_type_registry!
  end
end
