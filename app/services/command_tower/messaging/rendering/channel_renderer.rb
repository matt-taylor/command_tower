# frozen_string_literal: true

require "cgi"

module CommandTower
  module Messaging
    module Rendering
      class ChannelRenderer
        EMAIL_CHANNEL = "email"
        SMS_CHANNEL = "sms"
        PUSHOVER_CHANNEL = "pushover"
        PUSH_CHANNEL = "push"
        SUPPORTED_CHANNELS = [EMAIL_CHANNEL, SMS_CHANNEL, PUSHOVER_CHANNEL, PUSH_CHANNEL].freeze
        TEMPLATE_FILENAME_PATTERN = /\A(?<basename>[a-z]+)\.(?<format>html|text)\.erb\z/
        DEFAULT_TITLE = "Notification"

        def self.render(communication:, channel_key:, recipient_address:)
          new(
            communication:,
            channel_key:,
            recipient_address:,
          ).render
        end

        def self.supported_channel?(channel_key)
          SUPPORTED_CHANNELS.include?(channel_key.to_s)
        end

        def initialize(communication:, channel_key:, recipient_address:)
          @communication = communication
          @channel_key = channel_key.to_s
          @recipient_address = recipient_address
        end

        def render
          address = @recipient_address.to_s.strip
          raise RenderError.new(code: "recipient_missing") if address.empty?

          unless self.class.supported_channel?(@channel_key)
            raise RenderError.new(code: "render_failed", error_class: "UnsupportedChannel")
          end

          begin
            case @channel_key
            when EMAIL_CHANNEL
              render_email(address)
            when SMS_CHANNEL
              render_sms(address)
            when PUSHOVER_CHANNEL
              render_pushover(address)
            when PUSH_CHANNEL
              render_push(address)
            else
              raise RenderError.new(code: "render_failed", error_class: "UnsupportedChannel")
            end
          rescue RenderError
            raise
          rescue StandardError => error
            raise RenderError.new(code: "render_failed", error_class: error.class.name)
          end
        end

        private

        def render_email(address)
          RenderedPayload.build(
            recipient_address: address,
            subject: @communication.title.to_s,
            text_body: render_template("email.text.erb"),
            html_body: render_template("email.html.erb"),
          )
        end

        def render_sms(address)
          body = render_template("sms.text.erb").to_s.strip
          raise ArgumentError, "body is required" if body.empty?

          RenderedSmsPayload.build(
            recipient_address: address,
            body:,
          )
        end

        def render_pushover(address)
          title = notification_title
          message = render_template("pushover.text.erb").to_s.strip
          raise ArgumentError, "message is required" if message.empty?

          RenderedPushoverPayload.build(
            recipient_address: address,
            title:,
            message:,
          )
        end

        def render_push(address)
          title = notification_title
          body = render_template("push.text.erb").to_s.strip
          raise ArgumentError, "body is required" if body.empty?

          RenderedPushPayload.build(
            recipient_address: address,
            title:,
            body:,
            deep_link: template_locals[:deep_link],
          )
        end

        def notification_title
          title = @communication.title.to_s.strip
          return title unless title.empty?

          body = @communication.body.to_s.strip
          return body[0, 50] unless body.empty?

          DEFAULT_TITLE
        end

        alias pushover_title notification_title

        def render_template(filename)
          match = TEMPLATE_FILENAME_PATTERN.match(filename.to_s)
          raise Errno::ENOENT, "missing template #{filename}" unless match

          TemplateResolver.render(
            basename: match[:basename],
            format: match[:format].to_sym,
            notification_type_key: @communication.notification_type_key,
            generic_locals: template_locals,
            type_locals: type_template_locals,
          )
        end

        # ActionView's OutputBuffer auto-escapes any interpolated value that is
        # not marked `html_safe?`, for every format (html and text alike) —
        # see `ActionView::OutputBuffer#<<`. Generic templates historically
        # relied on plain ERB, which never auto-escaped anything; callers
        # (namely `email.html.erb`) explicitly call `h.call(...)` when they
        # want escaping. To preserve that exact contract under ActionView
        # rendering, `title`/`body`/`deep_link` are pre-marked `html_safe` (so
        # raw interpolation stays unescaped, matching legacy behavior) and
        # `h.call` marks its own already-escaped output `html_safe` too, so it
        # is not escaped a second time by the output buffer.
        def template_locals
          {
            title: @communication.title.to_s.html_safe,
            body: @communication.body.to_s.html_safe,
            deep_link: deep_link_from_metadata&.html_safe,
            h: ->(value) { CGI.escapeHTML(value.to_s).html_safe },
          }
        end

        def type_template_locals
          template_locals.merge(
            metadata: frozen_metadata,
            notification_type_key: @communication.notification_type_key.to_s,
          )
        end

        def deep_link_from_metadata
          metadata = @communication.metadata
          deep_link = metadata.is_a?(Hash) ? metadata["deep_link"] || metadata[:deep_link] : nil
          deep_link = deep_link.to_s if deep_link
          deep_link.presence
        end

        def frozen_metadata
          metadata = @communication.metadata
          return {}.freeze unless metadata.is_a?(Hash)

          metadata.to_h.transform_keys(&:to_s).freeze
        end
      end
    end
  end
end
