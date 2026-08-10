# frozen_string_literal: true

require "erb"
require "cgi"

module CommandTower
  module Messaging
    module Rendering
      class ChannelRenderer
        EMAIL_CHANNEL = "email"
        SMS_CHANNEL = "sms"
        PUSHOVER_CHANNEL = "pushover"
        SUPPORTED_CHANNELS = [EMAIL_CHANNEL, SMS_CHANNEL, PUSHOVER_CHANNEL].freeze
        TEMPLATE_DIR = CommandTower::Engine.root.join("app/views/command_tower/messaging/rendering")
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
          title = pushover_title
          message = render_template("pushover.text.erb").to_s.strip
          raise ArgumentError, "message is required" if message.empty?

          RenderedPushoverPayload.build(
            recipient_address: address,
            title:,
            message:,
          )
        end

        def pushover_title
          title = @communication.title.to_s.strip
          return title unless title.empty?

          body = @communication.body.to_s.strip
          return body[0, 50] unless body.empty?

          DEFAULT_TITLE
        end

        def render_template(filename)
          path = TEMPLATE_DIR.join(filename)
          raise Errno::ENOENT, "missing template #{filename}" unless path.file?

          template = ERB.new(path.read, trim_mode: "-")
          template.result_with_hash(template_locals)
        end

        def template_locals
          metadata = @communication.metadata
          deep_link = metadata.is_a?(Hash) ? metadata["deep_link"] || metadata[:deep_link] : nil
          deep_link = deep_link.to_s if deep_link

          {
            title: @communication.title.to_s,
            body: @communication.body.to_s,
            deep_link: deep_link.presence,
            h: ->(value) { CGI.escapeHTML(value.to_s) },
          }
        end
      end
    end
  end
end
