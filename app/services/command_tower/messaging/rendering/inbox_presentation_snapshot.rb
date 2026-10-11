# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Captures the first presentation node's projected data at Accept time.
      # Returns nil when the document has no presentation node. Returns an
      # omitted marker when a presentation node was seen and capture failed.
      # Never persists and never performs network I/O.
      class InboxPresentationSnapshot
        VERSION = 1

        def self.capture(communication:, recipient_id:)
          new(communication:, recipient_id:).capture
        end

        def self.omitted?(snapshot)
          snapshot.is_a?(Hash) && snapshot.stringify_keys["omitted"] == true
        end

        def initialize(communication:, recipient_id:)
          @communication = communication
          @recipient_id = recipient_id
        end

        def capture
          block = first_presentation_block
          return nil if block.nil?

          capture_seen_block(block)
        end

        private

        attr_reader :communication, :recipient_id

        def capture_seen_block(block)
          resolved = InboxPresentationResolver.resolve(communication:, recipient_id:, block:)
          resolved.nil? ? omitted_marker : payload(resolved)
        rescue StandardError
          omitted_marker
        end

        def first_presentation_block
          document = InboxDocumentRenderer.compose_shell(communication)
          document.blocks.find { |block| block[:type] == "presentation" }
        end

        def payload(resolved)
          {
            "v" => VERSION,
            "key" => resolved[:key].to_s,
            "variant" => resolved[:variant],
            "data" => resolved[:data].deep_stringify_keys,
          }
        end

        def omitted_marker
          { "v" => VERSION, "omitted" => true }
        end
      end
    end
  end
end
