# frozen_string_literal: true

# Auth mail is enqueued (config.login.mail_delivery = :later). Keep jobs out of
# async threads; specs that need delivery wrap the call in perform_enqueued_jobs.
RSpec.configure do |config|
  config.include ActiveJob::TestHelper, :perform_jobs
  config.before(:suite) { ActiveJob::Base.queue_adapter = :test }
end
