# frozen_string_literal: true

# Helpers for specs of the unauthenticated one-click unsubscribe endpoint.
module MessagingUnsubscribeHelper
  ENDPOINT = "/messaging/unsubscribe"
  CLIENT_HEADERS = { "REMOTE_ADDR" => "203.0.113.10" }.freeze

  def seed_unsubscribe_types!
    CommandTower.config.messaging.platform_enabled_channels = -> { %w[email] }
    register_and_seal_notification_types(*unsubscribe_type_declarations)
  end

  def unsubscribe_token_for(user_id:, key: "class_canceled")
    CommandTower::Services::Messaging::Unsubscribe::IssueToken.call(
      user_id:, notification_type_key: key
    ).data[:token]
  end

  def post_unsubscribe(value)
    post ENDPOINT, params: { token: value }, headers: CLIENT_HEADERS
  end

  def unsubscribe_audit_rows
    CommandTower::Audit::Event.where(action: "messaging_unsubscribed")
  end

  def email_permitted?(user, key = "class_canceled")
    CommandTower::Messaging::Preferences.resolve(
      notification_type_key: key, recipient_id: user.id, platform_enabled_channels: %w[email]
    ).permitted_channels.include?("email")
  end

  private

  def unsubscribe_type_declarations
    [
      unsubscribe_declaration(key: "class_canceled"),
      unsubscribe_declaration(key: "password_changed", user_configurable: false, mandatory: true),
      unsubscribe_declaration(
        key: "sms_only", allowed_channels: %w[sms], default_channels: %w[sms],
        default_preference_state: { "channels" => { "sms" => true } }
      )
    ]
  end

  def unsubscribe_declaration(key:, **overrides)
    build_notification_type_declaration(
      key:, label: key.humanize, allowed_channels: %w[email], settings_visible: true,
      default_preference_state: { "channels" => { "email" => true } }, **overrides
    )
  end
end

RSpec.configure do |config|
  config.include MessagingUnsubscribeHelper, :messaging_unsubscribe
  config.include MessagingNotificationTypesHelper, :messaging_unsubscribe

  config.around(:each, :messaging_unsubscribe) do |example|
    MessagingNotificationTypesHelper.reset_notification_type_registry!
    example.run
    MessagingNotificationTypesHelper.reset_notification_type_registry!
  end
end
