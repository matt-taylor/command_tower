# frozen_string_literal: true

# Helpers for specs that archive inbox rows and assert thread restore on a new Accept.
# Expects the including example group to define `user` and register "booking.success".
module MessagingThreadRestoreHelper
  def accept_in_thread(recipient: user, identity: SecureRandom.hex(6), conversation_key: "week-5")
    CommandTower::Messaging.accept(
      **default_accept_attrs(
        user: recipient,
        notification_type_key: "booking.success",
        platform_enabled_channels: %w[email],
        host_event_identity: identity,
        conversation_key:,
        conversation_title: conversation_key && "Thread"
      )
    )
  end

  def archive_inbox_item(result, **attrs)
    reloaded_inbox_item(result).update!({ archived_at: Time.current, status: "archived" }.merge(attrs))
  end

  def archived_accept_in_thread(**)
    accept_in_thread(**).tap { |result| archive_inbox_item(result) }
  end

  def reloaded_inbox_item(result)
    CommandTower::Messaging::InboxItem.find(result.inbox_item_id)
  end

  def inbox_item_archived?(result)
    reloaded_inbox_item(result).archived_at.present?
  end

  def stub_restore_members(&)
    allow(described_class).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap do |instance|
        allow(instance).to receive(:restore_members).and_wrap_original(&)
      end
    end
  end
end

RSpec.configure do |config|
  config.include MessagingThreadRestoreHelper, :messaging_thread_restore
end
