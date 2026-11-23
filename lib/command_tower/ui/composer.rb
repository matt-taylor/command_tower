# frozen_string_literal: true

module CommandTower
  module UI
    # Base class for host and platform document composers. A subclass implements
    # `compose(d, **inputs)` against the Builder and the class method returns a
    # validated Document:
    #
    #   class ClassCanceled < CommandTower::UI::Composer
    #     def compose(d, starts_at:)
    #       d.card { |c| c.text "Class canceled" }
    #     end
    #   end
    #
    #   ClassCanceled.call(starts_at: time)  # => CommandTower::UI::Document
    #
    # `text_fallback` is derived from the tree (see TextDerivation). A subclass
    # may override `text_fallback(root, **inputs)` to return its own string.
    #
    # Raises InvalidDocumentError (paths and codes only) when the result is not
    # valid. No registry (design D3).
    class Composer
      def self.call(**inputs)
        new.call(**inputs)
      end

      def call(**inputs)
        built = UI.document(text_fallback: "-") { |d| compose(d, **inputs) }
        built.validate! # the tree must be valid before text is derived from it
        fallback = text_fallback(built.root, **inputs) || TextDerivation.call(built.root)
        Document.new(root: built.root, text_fallback: fallback).validate!
      end

      # Subclasses implement this.
      def compose(_builder, **_inputs)
        raise NotImplementedError, "#{self.class.name} must implement compose(builder, **inputs)"
      end

      # Hook: return a String to replace the derived fallback, or nil to derive.
      def text_fallback(_root, **_inputs)
        nil
      end
    end
  end
end
