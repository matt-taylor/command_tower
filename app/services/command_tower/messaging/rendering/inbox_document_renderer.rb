# frozen_string_literal: true

require "uri"

module CommandTower
  module Messaging
    module Rendering
      # Internal Messaging::Rendering collaborator (peer of `ChannelRenderer`,
      # not a host-facing service). Builds the `InboxDocument` shown at Inbox
      # detail read time.
      #
      # Generic path: one `paragraph` block from `communication.body`, plus an
      # optional `cta` block with a typed `destination` — internal
      # (`metadata["deep_link_path"]`, origin-free, host-navigation-owned) if
      # present and safe, else external (`metadata["deep_link"]`) if that is
      # a safe href (D-INBOX-GENERIC; typed destination added Slice 2.6.4).
      #
      # Optional per-`notification_type_key` override: a pure-Ruby composer
      # class (`declaration.inbox_document_composer`, resolved via
      # `NotificationTypes.lookup` + `.constantize`), `.call(communication:) ->
      # InboxDocument`. Any failure (unregistered type, absent composer,
      # unresolvable class name, a raising composer, or a composer returning
      # something other than an `InboxDocument`) fails open to the generic
      # document — the Inbox read path must never 500 on a bad type composer
      # (D-INBOX-TYPE). This replaces the Rich Messaging Campaign 2 ERB/JSON
      # authoring path entirely — see
      # artifacts/visual-improvements/rich-messaging/authority/RICH_MESSAGING_RUBY_INBOX_DEFINITION_DISCOVERY.md.
      #
      # After the document (type-specific or generic) is built, any
      # `"presentation"` block is resolved against
      # `CommandTower.config.registry.inbox_presentations` — at most one
      # attempted/resolved presentation capability per document (Rich
      # Messaging Slice 2.5). The budget is consumed the instant a
      # `"presentation"`-typed block is seen, before lookup or composition,
      # regardless of outcome, so a malformed/unregistered first node cannot
      # fail open and then let a second node still execute composer domain
      # I/O.
      #
      # A stored `inbox_presentation_snapshot` replaces that live resolution.
      # Null means there is no retained presentation (legacy rows, or a
      # document with no presentation node) and the live composer still runs.
      # An omitted snapshot drops the presentation node and does not call
      # the composer. A stored payload is rendered as-is.
      #
      # The composer's raw result is always projected down to the
      # registration's declared `output_keys` before it reaches
      # `content.blocks[].data` (corrective slice — presentation
      # ServiceResult/context leak fix). Composer inputs and any other
      # incidental context/result keys never reach the wire, regardless of
      # whether the composer is `ApplicationService`-shaped or a plain Hash.
      class InboxDocumentRenderer
        UNSAFE_SCHEMES = %w[javascript data vbscript].freeze
        DEFAULT_CTA_LABEL = "Open"

        def self.render(communication:, recipient_id:)
          new(communication:, recipient_id:).render
        end

        def self.compose_shell(communication)
          new(communication:, recipient_id: nil).compose_shell
        end

        def initialize(communication:, recipient_id:)
          @communication = communication
          @recipient_id = recipient_id
          @presentation_attempted = false
        end

        def render
          document = compose_shell
          snapshot = stored_presentation_snapshot
          return resolve_presentation_blocks(document) if snapshot.nil?
          return drop_presentation_blocks(document) if InboxPresentationSnapshot.omitted?(snapshot)

          apply_stored_presentation(document, snapshot)
        end

        def compose_shell
          build_from_type_composer || build_generic
        end

        private

        attr_reader :communication, :recipient_id

        def build_from_type_composer
          declaration = CommandTower::Messaging::NotificationTypes.lookup(communication.notification_type_key)
          composer_name = declaration.inbox_document_composer
          return nil if composer_name.nil?

          document = composer_name.constantize.call(communication:)
          document.is_a?(InboxDocument) ? document : nil
        rescue StandardError
          # Fail-open: unregistered type, unresolvable class name, a raising
          # composer, or a composer returning invalid data must never surface
          # as a 500 on the Inbox read path (D-INBOX-TYPE).
          nil
        end

        def build_generic
          blocks = []
          blocks << paragraph_block(communication.body) if communication.body.present?
          cta = generic_cta_block
          blocks << cta if cta

          InboxDocument.build(blocks:)
        end

        # Re-walks the already-validated blocks array (produced either by a
        # trusted Ruby composer via `InboxDocument::Builder` or by
        # `build_generic`), resolving any `"presentation"` node in place.
        # There is no untrusted JSON to parse/whitelist here — every block was
        # already constructed via a whitelisted `Builder` method or this
        # class's own `paragraph_block`/`cta_block` helpers.
        def resolve_presentation_blocks(document)
          resolved = document.blocks.map do |block|
            block[:type] == "presentation" ? presentation_block(block) : block
          end.compact

          InboxDocument.build(blocks: resolved)
        end

        def presentation_block(block)
          return nil if @presentation_attempted

          @presentation_attempted = true
          InboxPresentationResolver.resolve(communication:, recipient_id:, block:)
        end

        def stored_presentation_snapshot
          raw = communication.inbox_presentation_snapshot
          return nil if raw.blank?
          return nil unless raw.respond_to?(:stringify_keys)

          raw.stringify_keys
        end

        def drop_presentation_blocks(document)
          InboxDocument.build(blocks: document.blocks.reject { |block| block[:type] == "presentation" })
        end

        def apply_stored_presentation(document, snapshot)
          applied = false
          blocks = document.blocks.filter_map do |block|
            next block unless block[:type] == "presentation"
            next nil if applied

            applied = true
            stored_presentation_block(snapshot)
          end

          InboxDocument.build(blocks:)
        end

        def stored_presentation_block(snapshot)
          data = snapshot["data"].respond_to?(:to_h) ? snapshot["data"].to_h.deep_symbolize_keys : {}
          {
            type: "presentation",
            key: snapshot["key"].to_s,
            variant: snapshot["variant"],
            data:,
          }.freeze
        end

        def paragraph_block(text)
          return nil unless text.is_a?(String)
          return nil if text.empty?

          { type: "paragraph", text: }.freeze
        end

        def generic_cta_block
          cta_block(
            label: metadata_value("cta_label"),
            path: metadata_value("deep_link_path"),
            href: metadata_value("deep_link")
          )
        end

        # Internal (`path`) takes precedence over external (`href`) when
        # both are present — a `cta` only ever means one navigation intent
        # (Slice 2.6.4 typed destination; see artifacts/visual-improvements/
        # rich-messaging/plans/2.6.4-ct-fe-inbox-navigation-capability.md).
        def cta_block(label:, path: nil, href: nil)
          destination = cta_destination(path:, href:)
          return nil unless destination

          resolved_label = label.is_a?(String) && !label.strip.empty? ? label : DEFAULT_CTA_LABEL
          { type: "cta", label: resolved_label, destination: }.freeze
        end

        def cta_destination(path:, href:)
          if safe_internal_path?(path)
            { kind: "internal", path: }
          elsif safe_href?(href)
            { kind: "external", href: }
          end
        end

        # A leading `//` is rejected even though it "starts with a slash" —
        # it is a protocol-relative URL, not a safe same-app-only destination.
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

        def metadata_value(key)
          metadata = communication.metadata
          return nil unless metadata.is_a?(Hash)

          metadata[key] || metadata[key.to_sym]
        end
      end
    end
  end
end
