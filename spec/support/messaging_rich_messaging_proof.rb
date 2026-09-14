# frozen_string_literal: true

module MessagingRichMessagingProofHelper
  FIXTURE_VIEW_PATH = File.expand_path("fixtures/messaging_rich_messaging_proof/views", __dir__)
end

RSpec.configure do |config|
  # Shared across every RM.1 fixture example: prepends one host-style view
  # root ahead of the real host and engine defaults, and resets it afterward,
  # mirroring the existing `:messaging_notification_types` reset pattern.
  config.around(:each, :messaging_rich_messaging_proof) do |example|
    CommandTower::Messaging::Rendering::TemplateResolver.prepend_view_path(
      MessagingRichMessagingProofHelper::FIXTURE_VIEW_PATH,
    )
    example.run
  ensure
    CommandTower::Messaging::Rendering::TemplateResolver.reset_view_paths!
  end
end
