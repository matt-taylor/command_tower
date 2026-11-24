# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # The per-channel payloads of a gallery preview. A channel the type does not allow is nil
        # (the inbox included, G16): the inbox is nil when no inbox document was composed.
        module PreviewChannels
          SLOT_NAMES = %i[headline subject push_body sms_body pushover_title pushover_message].freeze

          module_function

          def allowed?(declaration, channel)
            declaration.allowed_channels.to_a.include?(channel)
          end

          def slot_payload(slots)
            SLOT_NAMES.index_with { |name| slots[name] }
          end

          # @param inbox [Hash, nil] the inbox document wire hash
          # @param email [Hash, nil] the email preview
          def call(declaration:, slots:, link:, inbox:, email:)
            {
              push: (push(slots) if allowed?(declaration, "push")),
              sms: (sms(slots, link) if allowed?(declaration, "sms")),
              pushover: (pushover(slots, link) if allowed?(declaration, "pushover")),
              inbox: (inbox ? { content: inbox } : nil),
              email:
            }
          end

          def push(slots)
            title = slots[:headline].to_s
            { title:, body: (slots[:push_body] || title).to_s }
          end

          def sms(slots, link)
            { text: [slots[:sms_body], link].compact_blank.join(" ") }
          end

          def pushover(slots, link)
            { title: (slots[:pushover_title] || slots[:headline]).to_s,
              message: [slots[:pushover_message], link].compact_blank.join(" "), url: link }
          end
        end
      end
    end
  end
end
