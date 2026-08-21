# frozen_string_literal: true

module CommandTower
  module Messaging
    class ChannelMailer < ApplicationMailer
      def deliver_rendered(rendered:)
        unless rendered.is_a?(Rendering::RenderedPayload)
          raise ArgumentError, "rendered must be a RenderedPayload"
        end

        from_address = smtp_from_address

        mail(
          to: rendered.recipient_address,
          from: from_address,
          subject: rendered.subject,
        ) do |format|
          format.text { render plain: rendered.text_body }
          format.html { render html: rendered.html_body.html_safe }
        end
      end
    end
  end
end
