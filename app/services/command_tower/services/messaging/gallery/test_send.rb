# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Builds the email of a gallery test send: one declared fixture of one defined type, rendered
        # like the gallery email preview, addressed to the real actor's own address.
        #
        # - Email only. A type that does not allow email is a ValidationError.
        # - Reads no `Communication` and writes none. It does not send; the workflow hands the content
        #   to the adapter boundary.
        # - The subject is the preview subject, unchanged. A "Test message" line sits above the
        #   compliance footer. No `List-Unsubscribe*` headers are produced (the content has none).
        #
        # Output: `recipient` (the actor's address, from the user record) and `content`
        # (`subject`, `html`, `text`).
        class TestSend < CommandTower::Services::ApplicationService
          NOTICE = "Test message"

          validate :notification_type_key, is_a: String, required: true
          validate :fixture, is_a: String, required: false
          validate :zone, is_a: String, required: false
          validate :actor, is_a: User, required: true

          def call
            address = actor.email.to_s.strip
            return fail_with(recipient: "has no email address") if address.empty?

            email = email_preview
            return fail_with(channel: "email is not allowed for this notification type") unless email

            context.recipient = address
            context.content = email.slice(:subject, :html, :text)
          end

          private

          def email_preview
            rendered = CommandTower::Services::Messaging::Gallery::RenderGalleryPreview.call(
              notification_type_key:, fixture:, zone:, footer_notice: NOTICE
            )
            context.fail!(application_error: rendered.errors.first) unless rendered.success?

            rendered.data[:preview].dig(:channels, :email)
          end

          def fail_with(details)
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
          end
        end
      end
    end
  end
end
