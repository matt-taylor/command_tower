# frozen_string_literal: true

require_relative "messaging_notification_types"
require_relative "messaging_preferences"

module MessagingAcceptHelper
  module_function

  def default_accept_attrs(user:, **overrides)
    {
      recipient_id: user.id,
      notification_type_key: "booking.success",
      host_event_identity: "reservation-123",
      title: "Booking confirmed",
      body: "Your booking was confirmed.",
      metadata: { "deep_link" => "/bookings/1" },
      preference_state: nil,
      platform_enabled_channels: %w[email sms],
      message_overrides: nil,
    }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include MessagingAcceptHelper, :messaging_accept
  config.include MessagingNotificationTypesHelper, :messaging_accept
  config.include MessagingPreferencesHelper, :messaging_accept
  config.include ActiveJob::TestHelper, :messaging_accept

  config.around(:each, :messaging_accept) do |example|
    MessagingNotificationTypesHelper.reset_notification_type_registry!
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
    MessagingNotificationTypesHelper.reset_notification_type_registry!
  end
end
