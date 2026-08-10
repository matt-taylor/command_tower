# frozen_string_literal: true

module MessagingInboxHelper
  module_function

  def create_inbox_for(user:, **inbox_attrs)
    communication = create(:messaging_communication, user:)
    create(:messaging_inbox_item, communication:, **inbox_attrs)
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
