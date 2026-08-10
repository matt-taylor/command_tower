# frozen_string_literal: true

module MessagingPreferencesHelper
  module_function

  def build_preference_state(channels: {}, inbox: nil)
    state = { "channels" => channels }
    state["inbox"] = inbox unless inbox.nil?
    state
  end

  def upsert_notification_preference!(recipient_id:, notification_type_key:, preference_state:)
    CommandTower::Messaging::Preferences.upsert_stored!(
      recipient_id:,
      notification_type_key:,
      preference_state:,
    )
  end
end

RSpec.configure do |config|
  config.include MessagingPreferencesHelper, :messaging_preferences
  config.include MessagingNotificationTypesHelper, :messaging_preferences

  config.around(:each, :messaging_preferences) do |example|
    MessagingNotificationTypesHelper.reset_notification_type_registry!
    example.run
    MessagingNotificationTypesHelper.reset_notification_type_registry!
  end
end
