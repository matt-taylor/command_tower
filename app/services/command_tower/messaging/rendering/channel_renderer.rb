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

        def self.render(communication:, channel_key:, recipient_address:, channel_delivery: nil)
          new(
            communication:,
            channel_key:,
            recipient_address:,
            channel_delivery:,
          ).render
        end

        def self.supported_channel?(channel_key)
          SUPPORTED_CHANNELS.include?(channel_key.to_s)
        end

        def initialize(communication:, channel_key:, recipient_address:, channel_delivery: nil)
          @communication = communication
          @channel_key = channel_key.to_s
          @recipient_address = recipient_address
          @channel_delivery = channel_delivery
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
          definition = email_definition
          return render_generic_email(address) unless definition

          render_defined_email(address, definition)
        end

        def render_generic_email(address, subject: @communication.title.to_s)
          RenderedPayload.build(
            recipient_address: address,
            subject:,
            text_body: render_template("email.text.erb"),
            html_body: render_template("email.html.erb"),
          )
        end

        # Defined types: subject from the stored `subject` slot, document through the email
        # composer, then the CT fallback document, then the generic ERBs (design D20).
        def render_defined_email(address, definition)
          subject = slot("subject") || @communication.title.to_s
          output = DefinedEmailRenderer.render(communication: @communication, definition:)
          RenderedPayload.build(recipient_address: address, subject:, text_body: output.text, html_body: output.html)
        rescue StandardError => error
          log_erb_fallback(error)
          render_generic_email(address, subject:)
        end

        # The declared MessageDefinition class for a defined communication, else nil.
        def email_definition
          return nil unless @communication.message_definition_backed?

          name = NotificationTypes.lookup(@communication.notification_type_key).message
          name.presence&.constantize
        rescue StandardError
          nil
        end

        def log_erb_fallback(error)
          Rails.logger.warn(
            "[command_tower] email_erb_fallback communication_id=#{@communication.id} " \
            "notification_type_key=#{@communication.notification_type_key} error_class=#{error.class.name}"
          )
        end

        def render_sms(address)
          body = slot("sms_body") ? with_deep_link(slot("sms_body")) : render_template("sms.text.erb").to_s.strip
          raise ArgumentError, "body is required" if body.empty?

          RenderedSmsPayload.build(
            recipient_address: address,
            body:,
          )
        end

        def render_pushover(address)
          if slot("pushover_message")
            title = slot("pushover_title") || slot("headline") || notification_title
            message = with_deep_link(slot("pushover_message"))
          else
            title = notification_title
            message = render_template("pushover.text.erb").to_s.strip
          end
          raise ArgumentError, "message is required" if message.empty?

          RenderedPushoverPayload.build(
            recipient_address: address,
            title:,
            message:,
          )
        end

        def render_push(address)
          if slot("headline")
            title = slot("headline")
            body = slot("push_body") || title
          else
            title = notification_title
            body = render_template("push.text.erb").to_s.strip
          end
          raise ArgumentError, "body is required" if body.empty?

          deep_link = resolve_push_deep_link
          presentation = PushPresentation.call(communication: @communication, channel_delivery: @channel_delivery)

          RenderedPushPayload.build(
            recipient_address: address,
            title:,
            body:,
            deep_link:,
            sound: presentation.sound,
            urgency: presentation.urgency,
            thread_id: presentation.thread_id,
            badge: presentation.badge,
          )
        end

        # Stored slot text for a MessageDefinition-backed communication (D24); nil for undefined
        # types and blank slots, which keep the generic ERBs. Slots are stored at Accept, never re-run.
        def slot(name)
          return nil unless @communication.message_definition_backed?

          stored = @communication.slots
          return nil unless stored.respond_to?(:to_h)

          stored.to_h.transform_keys(&:to_s)[name].to_s.strip.presence
        end

        def with_deep_link(text)
          link = deep_link_from_metadata
          link ? "#{text} #{link}" : text
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

        # Metadata deep_link wins. A live inbox item is a destination by itself.
        # Otherwise substitute the host Home link. Never invent a link.
        def resolve_push_deep_link
          existing = deep_link_from_metadata
          return existing if existing
          return nil if live_inbox_item

          home = CommandTower.config.messaging.expo.resolve_home_deep_link
          if home.nil?
            log_push_destination_fallback(reason_code: "home_deep_link_unresolved", level: :error)
            raise RenderError.new(code: "render_failed", error_class: "HomeDeepLinkUnresolved")
          end

          if inbox_preference_disabled?
            log_push_destination_fallback(reason_code: "inbox_disabled", level: :info)
          else
            log_push_destination_fallback(reason_code: "destination_missing", level: :error)
          end
          home
        end

        def live_inbox_item
          item = @communication.inbox_item
          return nil unless item&.live_for_push?

          item
        end

        def inbox_preference_disabled?
          decision = @communication.destination_plan&.decision
          return false unless decision.is_a?(Hash)

          excluded = decision["excluded_destinations"] || decision[:excluded_destinations]
          Array(excluded).any? do |item|
            next false unless item.is_a?(Hash)

            destination = (item["destination"] || item[:destination]).to_s
            reason = (item["reason_class"] || item[:reason_class]).to_s
            destination == "inbox" && reason == Preferences::ReasonClasses::SUPPRESSED_BY_PREFERENCE
          end
        end

        def log_push_destination_fallback(reason_code:, level:)
          Execution::OperationLogger.push_destination_fallback(
            communication: @communication,
            reason_code:,
            level:,
            channel_delivery: @channel_delivery,
          )
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
