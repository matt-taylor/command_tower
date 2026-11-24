# frozen_string_literal: true

require "json"

# Message fixtures for the sample message types of the rails_app host. `rake
# command_tower:messaging:fixtures` writes them; a spec checks the committed files equal a fresh
# render, so the frontend and the preview app can copy them byte for byte.
#
#   spec/fixtures/ui/documents/   inbox documents (catalog 2 `UI::Document` JSON)
#   spec/fixtures/ui/email/       email HTML and text parts
#   spec/fixtures/messaging/gallery/  admin gallery list and preview payloads (wire form)
#
# Everything renders through the production code paths (the inbox renderer, the email renderer, the
# gallery services and serializer) from the definitions' declared fixtures. Values are fictional.
# The notification types must be registered (the host initializer does it).
module MessagingFixtures
  ROOT = File.expand_path("../../spec/fixtures", __dir__)
  DOCUMENTS_DIR = File.join(ROOT, "ui/documents")
  EMAIL_DIR = File.join(ROOT, "ui/email")

  STUDIO_ZONE = "America/Los_Angeles"
  USER_ZONE = "America/New_York"

  # A definition whose inbox composer always fails; the `:basic` document is the fallback.
  class FailingInbox < ClassCanceled
    def inbox(_builder, **)
      raise "composer unavailable"
    end
  end

  # file name (no extension) => [notification type key, definition, fixture, zone, impersonating]
  DOCUMENTS = {
    "sample_inbox" => ["class_canceled", ClassCanceled, "default", STUDIO_ZONE, false],
    "sample_inbox_user_zone" => ["membership_renewal", MembershipRenewal, "default", USER_ZONE, false],
    "check_in_ready_inbox" => ["check_in_ready", CheckInReady, "default", STUDIO_ZONE, false],
    "sample_inbox_impersonated" => ["check_in_ready", CheckInReady, "default", STUDIO_ZONE, true],
    "sample_inbox_fallback" => ["class_canceled", FailingInbox, "other_zone", STUDIO_ZONE, false],
    "announcement_inbox" => [
      "promotional_announcement", CommandTower::Messaging::AnnouncementDefinition, "default", STUDIO_ZONE, false
    ]
  }.freeze

  # fixture name => `MessageDefinitionPreview` method
  EMAILS = {
    "class_canceled_email_defined" => :sample_email,
    "class_canceled_email_fallback" => :sample_email_fallback,
    "announcement_email" => :announcement_email,
    "announcement_email_without_api_base_url" => :announcement_email_without_api_base_url,
    "sample_email_user_zone" => :sample_email_user_zone
  }.freeze

  class << self
    # @return [Hash{String => String}] absolute path => file content, in write order
    def files
      document_files.merge(email_files, gallery_files)
    end

    def write_all
      files.each do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
    end

    private

    def document_files
      DOCUMENTS.to_h do |name, (key, definition, fixture, zone, impersonating)|
        [File.join(DOCUMENTS_DIR, "#{name}.json"), json(inbox_document(key, definition, fixture, zone, impersonating))]
      end
    end

    def inbox_document(key, definition, fixture, zone, impersonating)
      communication = communication_for(key, definition, fixture, zone)
      return basic_fallback(communication, definition).as_json if definition <= FailingInbox

      CommandTower::Messaging::Rendering::InboxDocumentRenderer.render(
        communication:, recipient_id: nil, ui_catalog: 2, impersonating:
      ).as_json
    end

    # What `InboxDocumentRenderer` renders in production when the composer raises.
    def basic_fallback(communication, definition)
      basic = Class.new(definition) do
        def inbox(builder, **)
          builder.basic
        end
      end
      CommandTower::Messaging::Definitions::DocumentBuilder.inbox(
        definition: basic.new, context: render_context(communication), profile: definition.document_profile
      )
    end

    def render_context(communication)
      CommandTower::Messaging::Definitions::RenderContext.new(
        notification_type_key: communication.notification_type_key, metadata: communication.metadata,
        metadata_version: communication.metadata_version, slots: communication.slots,
        render_zone: communication.render_zone
      )
    end

    # An unsaved Communication with the slots Accept would resolve.
    def communication_for(key, definition, fixture, zone)
      metadata = definition.fixtures.fetch(fixture)
      resolution = CommandTower::Messaging::Accept::ResolveCommunicationSlots.call(
        notification_type_key: key, definition:, metadata:, recipient_id: nil
      )
      CommandTower::Messaging::Communication.new(
        id: 1, notification_type_key: key, title: resolution.title, body: resolution.body,
        metadata:, metadata_version: resolution.metadata_version, slots: resolution.slots, render_zone: zone
      )
    end

    def email_files
      require Rails.root.join("test/mailers/previews/message_definition_preview").to_s
      EMAILS.each_with_object({}) do |(name, preview), files|
        mail = MessageDefinitionPreview.new.public_send(preview)
        files.merge!(email_path(name, "html") => mail.html_part.body.decoded,
                     email_path(name, "txt") => mail.text_part.body.decoded)
      end
    end

    def email_path(name, extension)
      File.join(EMAIL_DIR, "#{name}.#{extension}")
    end

    def gallery_files
      GalleryFixtures.values.transform_values { |value| json(value) }
    end

    # Pretty-printed JSON with deeply sorted keys and a trailing newline.
    def json(value)
      "#{JSON.pretty_generate(sort_keys(value.as_json))}\n"
    end

    def sort_keys(value)
      case value
      when Hash then value.sort_by { |key, _| key.to_s }.to_h { |key, inner| [key, sort_keys(inner)] }
      when Array then value.map { |inner| sort_keys(inner) }
      else value
      end
    end
  end
end

require_relative "messaging_fixtures/gallery_fixtures"
