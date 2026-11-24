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

  # A promotional definition: its footer adds `config.messaging.compliance.postal_address` and the
  # "Unsubscribe or manage email preferences" link copy (states E-03).
  class PromotionalClassCanceled < ClassCanceled
    promotional true
  end

  # Composer output, rendered in the studio zone, with the transactional footer (states E-01).
  def sample_email = message(ClassCanceled, zone: STUDIO_ZONE)

  # Promotional footer variant: postal address plus the unsubscribe-or-manage link.
  def sample_email_promotional = message(PromotionalClassCanceled, zone: STUDIO_ZONE)

  # The footer when `compliance.api_base_url` is unset. The footer is identical to `sample_email`: it
  # never carries a token and does not depend on the one-click headers, which are omitted in that case
  # (headers are set by `ChannelRenderer`, not by the body render this preview shows).
  def sample_email_without_api_base_url = message(ClassCanceled, zone: STUDIO_ZONE)

  # Composer failure: the CT fallback document.
  def sample_email_fallback = message(FailingComposer, zone: STUDIO_ZONE)

  # A user-zone definition (`MembershipRenewal` shows times in the recipient's zone) rendered for a
  # recipient whose zone differs from the default (the `:auto` zone label shows). `ClassCanceled` uses a
  # fixed studio time, so the recipient zone would have no effect on it.
  def sample_email_user_zone = message(MembershipRenewal, zone: USER_ZONE, key: "membership_renewal")

  private

  def message(definition, zone:, key: "class_canceled")
    communication = communication_for(definition, zone:, key:)
    output = CommandTower::Messaging::Rendering::DefinedEmailRenderer.render(communication:, definition:)
    UiDocumentMailer.document_email(html: output.html, text: output.text, subject: communication.slots.fetch("subject"))
  end

  def communication_for(definition, zone:, key:)
    metadata = definition.fixtures.fetch("default")
    resolution = CommandTower::Messaging::Accept::ResolveCommunicationSlots.call(
      notification_type_key: key, definition:, metadata:, recipient_id: nil
    )
    CommandTower::Messaging::Communication.new(
      id: 1, notification_type_key: key, title: resolution.title, body: resolution.body,
      metadata:, metadata_version: resolution.metadata_version, slots: resolution.slots, render_zone: zone
    )
  end
end
