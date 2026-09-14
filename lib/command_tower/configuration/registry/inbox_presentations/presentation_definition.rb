# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module InboxPresentations
        class PresentationDefinition
          include ClassComposer::Generator

          add_composer :composer_class,
            desc: "String class name of the registered presentation composer " \
                  "(`.call(communication:, recipient_id:) -> Hash`), resolved via `.constantize` " \
                  "at InboxDocumentRenderer render time — never at registration time",
            allowed: String,
            default: ""

          # Explicit output projection (Rich Messaging corrective slice —
          # ServiceResult/context leak fix). `InboxDocumentRenderer#presentation_block`
          # slices the composer's raw result down to exactly these keys before
          # it ever reaches `content.blocks[].data` — every other key (declared
          # `ApplicationService` inputs, incidental intermediate context state,
          # or anything else a composer happens to set) is dropped
          # unconditionally, regardless of whether the composer is an
          # `ApplicationService` or a plain Hash-returning class. This is a
          # declared allow-list owned by the registration, not an inference
          # from `ServiceResult`/`ApplicationService` argument metadata.
          add_composer :output_keys,
            desc: "Array of Symbol keys that are the ONLY keys copied from the composer's " \
                  "result onto the Inbox wire (`content.blocks[].data`) — every other " \
                  "context/result key (composer inputs, intermediate state, anything else) " \
                  "is dropped at render time, regardless of composer shape",
            allowed: Array,
            default: []

          attr_accessor :owner, :id

          def validate_definition!(key:)
            self.id = key.to_s
            self.owner = owner&.to_sym || :host
            self.composer_class = require_present_string!(composer_class, field: "composer_class", key:)
            self.output_keys = require_present_output_keys!(output_keys, key:)
          end

          private

          def require_present_string!(value, field:, key:)
            text = value.to_s.strip
            if text.empty?
              raise CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
                "inbox presentation #{key} is missing #{field}"
            end

            text
          end

          def require_present_output_keys!(value, key:)
            keys = Array(value).map { |entry| entry.to_s.strip }
            if keys.empty? || keys.any?(&:empty?)
              raise CommandTower::InboxPresentations::InvalidPresentationDefinitionError,
                "inbox presentation #{key} is missing output_keys"
            end

            keys.map(&:to_sym)
          end
        end
      end
    end
  end
end
