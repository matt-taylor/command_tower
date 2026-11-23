# frozen_string_literal: true

module CommandTower
  module UI
    module Fragments
      # A tinted card with a title and body paragraphs. Informational only: no
      # acknowledge or dismiss control.
      class NoticeFrame < Fragment
        attribute :title, :string
        attribute :tone, :string, default: "neutral"
        attribute :body, default: -> { [] }

        validates :title, presence: true
        validates :tone, inclusion: { in: Tokens::TONE }
        validate :body_is_list_of_strings

        def compose(builder)
          builder.card(surface: :tinted, tone:, padding: :lg) do |c|
            c.stack(gap: :sm) do |s|
              s.text(title, variant: :heading_m)
              Array(body).each { |paragraph| s.text(paragraph, variant: :body) }
            end
          end
        end

        private

        def body_is_list_of_strings
          return if body.is_a?(Array) && body.all?(String)

          errors.add(:body, :invalid)
        end
      end
    end
  end
end
