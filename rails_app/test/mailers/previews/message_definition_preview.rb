# frozen_string_literal: true

# Mailer preview for MessageDefinition-backed emails: /rails/mailers/message_definition/<preview>.
# Each preview builds an unsaved Communication from the `ClassCanceled` sample definition (fixed
# fictional metadata, slots resolved the way Accept resolves them) and renders it through
# `Messaging::Rendering::DefinedEmailRenderer`, the email path `ChannelRenderer` uses for defined types.
class MessageDefinitionPreview < ActionMailer::Preview
  STUDIO_ZONE = "America/Los_Angeles"
  USER_ZONE = "America/New_York"

  # A definition whose composer always fails, so the CT fallback document renders (design D20).
  # The fallback still derives the fact text from `facts` and builds the CTA from `deep_link_path`.
  class FailingComposer < ClassCanceled
    def email(_builder, **)
      raise "composer unavailable"
    end
  end

  # Composer output, rendered in the studio zone.
  def sample_email = message(ClassCanceled, zone: STUDIO_ZONE)

  # Composer failure: the CT fallback document.
  def sample_email_fallback = message(FailingComposer, zone: STUDIO_ZONE)

  # Composer output for a recipient whose zone differs from the studio's (the `:auto` zone label shows).
  def sample_email_user_zone = message(ClassCanceled, zone: USER_ZONE)

  private

  def message(definition, zone:)
    communication = communication_for(definition, zone:)
    output = CommandTower::Messaging::Rendering::DefinedEmailRenderer.render(communication:, definition:)
    UiDocumentMailer.document_email(html: output.html, text: output.text, subject: communication.slots.fetch("subject"))
  end

  def communication_for(definition, zone:)
    metadata = definition.fixtures.fetch("default")
    resolution = CommandTower::Messaging::Accept::ResolveCommunicationSlots.call(
      notification_type_key: "class_canceled", definition:, metadata:, recipient_id: nil
    )
    CommandTower::Messaging::Communication.new(
      id: 1, notification_type_key: "class_canceled", title: resolution.title, body: resolution.body,
      metadata:, metadata_version: resolution.metadata_version, slots: resolution.slots, render_zone: zone
    )
  end
end
