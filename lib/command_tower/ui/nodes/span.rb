# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Inline run of text inside `text` and `banner`. `text` spans may be
      # strong; `link` spans carry a navigate action. No HTML or markdown.
      class Span < Base
        TYPES = %w[text link].freeze

        attribute :type, :string, default: "text"
        field :text, :string
        field :strong, :boolean
        field :action

        validates :type, inclusion: { in: TYPES }
        validates :text, presence: true
        validate :action_matches_type

        def self.link(text, action:)
          new(type: "link", text:, action:)
        end

        def wire_type
          type
        end

        def each_child
          yield "action", action if action.is_a?(Base)
        end

        private

        def action_matches_type
          if type == "link"
            errors.add(:action, :invalid_action) unless action.is_a?(Action::Navigate)
          elsif !action.nil?
            errors.add(:action, :not_allowed)
          end
        end
      end

      # ActiveModel type for `spans`: plain strings become text spans.
      class SpanListType < ActiveModel::Type::Value
        private

        def cast_value(value)
          return value unless value.is_a?(Array)

          value.map { |item| item.is_a?(String) ? Span.new(text: item) : item }
        end
      end

      # Shared by `text` and `banner`.
      module Spanned
        def self.included(base)
          base.field :spans, SpanListType.new, default: -> { [] }
          base.validate :spans_are_valid_list
        end

        def each_child(&)
          nested_objects("spans", spans, &)
        end

        private

        def spans_are_valid_list
          return errors.add(:spans, :invalid_child) unless spans.is_a?(Array) && spans.all?(Span)

          errors.add(:spans, :blank) if spans.empty?
          errors.add(:spans, :too_many_spans) if spans.length > Limits::MAX_SPANS
        end
      end
    end
  end
end
