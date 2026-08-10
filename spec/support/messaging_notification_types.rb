# frozen_string_literal: true

module MessagingNotificationTypesHelper
  module_function

  def reset_notification_type_registry!
    CommandTower::Messaging::NotificationTypes.reset!
  end

  def build_notification_type_declaration(**overrides)
    attrs = {
      key: "example.type",
      allowed_channels: %w[email sms],
      default_channels: %w[email],
      inbox_available: true,
      user_configurable: true,
      mandatory: false,
      default_preference_state: {
        "channels" => { "email" => true, "sms" => true },
        "inbox" => true,
      },
      label: "Example Type",
      category_key: "example",
      category_label: "Example",
      category_order: 10,
      type_order: 10,
    }.merge(overrides)

    CommandTower::Messaging::NotificationTypes::Declaration.build(**attrs)
  end

  def register_and_seal_notification_types(*declarations)
    reset_notification_type_registry!
    declarations.each do |declaration|
      CommandTower::Messaging::NotificationTypes.register(declaration)
    end
    CommandTower::Messaging::NotificationTypes.seal
  end
end

RSpec.configure do |config|
  config.include MessagingNotificationTypesHelper, :messaging_notification_types

  config.around(:each, :messaging_notification_types) do |example|
    MessagingNotificationTypesHelper.reset_notification_type_registry!
    example.run
    MessagingNotificationTypesHelper.reset_notification_type_registry!
  end
end
