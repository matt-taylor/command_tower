# frozen_string_literal: true

module CommandTower
  module UI
    # Pure transform for impersonated inbox reads: every `code` node becomes a
    # plain `text` node (variant body, textTone secondary, label dropped) so the
    # code value never reaches the serialised document. Returns a new Document
    # and never mutates its input.
    #
    # `impersonating:` must be exactly false to skip redaction; any other value
    # (including nil, "unknown") redacts.
    module Redaction
      REPLACEMENT_TEXT = "Open the app to check in"

      def self.call(document, impersonating:)
        return document if impersonating == false

        Document.new(root: redact(document.root), text_fallback: document.text_fallback)
      end

      def self.redact(node)
        case node
        when Nodes::Code then replacement
        when Nodes::Container then copy_with(node, children: node.children.map { |child| redact(child) })
        when Nodes::Component then copy_with(node, fallback: redact(node.fallback))
        else node
        end
      end
      private_class_method :redact

      def self.copy_with(node, **attributes)
        copy = node.dup
        attributes.each { |name, value| copy.public_send(:"#{name}=", value) }
        copy
      end
      private_class_method :copy_with

      def self.replacement
        Nodes::Text.new(spans: [REPLACEMENT_TEXT], variant: "body", text_tone: "secondary")
      end
      private_class_method :replacement
    end
  end
end
