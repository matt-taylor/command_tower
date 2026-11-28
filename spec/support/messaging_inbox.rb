# frozen_string_literal: true

module MessagingInboxHelper
  module_function

  def create_inbox_for(user:, **inbox_attrs)
    communication = create(:messaging_communication, user:)
    create(:messaging_inbox_item, communication:, **inbox_attrs)
  end

  def inbox_data = response.parsed_body["data"]

  def inbox_unread_meta = response.parsed_body.dig("meta", "unreadCount")

  def inbox_viewed_events = CommandTower::Audit::Event.where(action: "messaging_inbox_item_viewed")

  def post_inbox_views(ids, request_headers)
    post "/me/inbox/views", params: { ids: }, headers: request_headers, as: :json
  end

  def post_inbox_mark_all_read(up_to, user)
    post "/me/inbox/mark-all-read", params: { upTo: up_to },
                                    headers: authenticate_request_with_bearer!(user), as: :json
  end
end

RSpec.configure do |config|
  config.include MessagingInboxHelper, :messaging_inbox
  config.include ActiveJob::TestHelper, :messaging_inbox

  config.around(:each, :messaging_inbox) do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end
end
