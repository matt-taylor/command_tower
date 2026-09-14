# frozen_string_literal: true

require "uri"

module CommandTower
  module Messaging
    module Rendering
      # Frozen v1 Inbox content document. Rendered at read (never persisted) by
      # `InboxDocumentRenderer`. Blocks are plain frozen Hashes, not nested
      # `Data` objects, so `#to_h` is already the exact JSON-serializable shape
      # the `content` response key needs — no extra conversion at the
      # serializer boundary.
      #
      # This value object only guarantees the envelope (`schema` tag, `blocks`
      # is an Array); block-level construction and validation is
      # `InboxDocumentRenderer`'s responsibility.
      InboxDocument = Data.define(:schema, :blocks)

      # Reopened (rather than defined inside the `Data.define` block) so that
      # `SCHEMA_V1` and `.build` attach to `InboxDocument` under normal
      # lexical constant scoping — a block passed to `Data.define` does not
      # change the lexical scope for constant assignment the way `class ...
      # end` does.
      class InboxDocument
        SCHEMA_V1 = "inbox_document_v1"

        def self.build(blocks:)
          raise ArgumentError, "blocks must be an Array" unless blocks.is_a?(Array)
          raise ArgumentError, "arbitrary hashes are not accepted as blocks entries" if blocks.any? { |b| !b.is_a?(Hash) }

          new(schema: SCHEMA_V1, blocks: blocks.freeze).freeze
        end

        # Small pure-Ruby authoring DSL (Rich Messaging Slice 2.5 revision —
        # replaces `inbox_document.json.erb` entirely; see
        # artifacts/visual-improvements/rich-messaging/authority/RICH_MESSAGING_RUBY_INBOX_DEFINITION_DISCOVERY.md).
        # A notification-type Inbox document composer calls `.compose` and
        # authors an ordered document via exactly three methods:
        #
        #   doc.paragraph "..."
        #   doc.cta "label", path: "/internal/route"
        #   doc.cta "label", href: "https://external.example/..."
        #   doc.presentation "pickem.make_picks", variant: :compact
        #
        # `cta` takes exactly one of `path:` (an internal, origin-free
        # destination the host's own navigation owns) or `href:` (an
        # absolute external URL opened via the platform's normal external-
        # link handling). The composer — which already knows whether a
        # destination is its own app's route or a third-party URL — states
        # that intent explicitly via a typed `destination`, rather than
        # having the frontend infer it from an absolute URL (Slice 2.6.4;
        # see artifacts/visual-improvements/rich-messaging/plans/
        # 2.6.4-ct-fe-inbox-navigation-capability.md).
        # `presentation` intentionally has no `data:`/`props:` argument at
        # all — the message type may only *name* a registered presentation
        # capability. Its data is composed separately, post-authoring, by
        # `InboxDocumentRenderer` and the registered presentation composer
        # (Rich Messaging Presentation Authority §8). There is no argument
        # slot to violate that boundary with.
        def self.compose
          builder = Builder.new
          yield builder
          build(blocks: builder.blocks)
        end

        class Builder
          UNSAFE_SCHEMES = %w[javascript data vbscript].freeze
          DEFAULT_CTA_LABEL = "Open"

          def initialize
            @blocks = []
          end

          def paragraph(text)
            return self unless text.is_a?(String) && !text.empty?

            @blocks << { type: "paragraph", text: }.freeze
            self
          end

          def cta(label, path: nil, href: nil)
            destination = cta_destination(path:, href:)
            return self unless destination

            resolved_label = label.is_a?(String) && !label.strip.empty? ? label : DEFAULT_CTA_LABEL
            @blocks << { type: "cta", label: resolved_label, destination: }.freeze
            self
          end

          def presentation(key, variant: nil)
            @blocks << { type: "presentation", key: key.to_s, variant: variant&.to_s }.freeze
            self
          end

          def blocks
            @blocks
          end

          private

          # Internal takes precedence when both are supplied — a `cta` only
          # ever means one navigation intent, and a composer that mistakenly
          # supplies both almost certainly means the internal one.
          def cta_destination(path:, href:)
            if safe_internal_path?(path)
              { kind: "internal", path: }
            elsif safe_href?(href)
              { kind: "external", href: }
            end
          end

          # A leading `//` is rejected even though it "starts with a slash" —
          # it is a protocol-relative URL (browsers/RN resolve it against
          # whatever scheme is active), not a safe same-app-only destination.
          def safe_internal_path?(path)
            path.is_a?(String) && path.start_with?("/") && !path.start_with?("//")
          end

          def safe_href?(href)
            return false unless href.is_a?(String) && !href.strip.empty?

            scheme = URI.parse(href).scheme&.downcase
            scheme.present? && UNSAFE_SCHEMES.exclude?(scheme)
          rescue URI::InvalidURIError
            false
          end
        end
      end
    end
  end
end
