# frozen_string_literal: true

module CommandTower
  module UI
    module Fragments
      # Vertical header (UX gap G1: the catalog has no horizontal layout):
      # avatar?, badge?, then title and subtitle.
      #
      #   d.fragment(Header, title: "Class canceled", subtitle: "Studio B",
      #                      badge_label: "Canceled", badge_tone: :danger,
      #                      avatar: { initials: "SB" })
      class Header < Fragment
        attribute :title, :string
        attribute :subtitle, :string
        attribute :badge_label, :string
        attribute :badge_tone, :string
        # Hash with symbol keys of Builder#avatar arguments (`src:`/`initials:`/`alt:`); size is fixed to md.
        attribute :avatar

        validates :title, presence: true
        validates :badge_tone, presence: true, if: -> { badge_label.present? }
        validate :avatar_is_hash_or_nil

        def compose(builder)
          builder.stack(gap: :sm, align: :start) do |s|
            compose_identity(s)
            compose_titles(s)
          end
        end

        private

        def compose_identity(builder)
          builder.avatar(**avatar, size: :md) if avatar
          builder.badge(badge_label, tone: badge_tone) if badge_label.present?
        end

        def compose_titles(builder)
          builder.stack(gap: :xs) do |s|
            s.text(title, variant: :heading_m)
            s.text(subtitle, variant: :subtitle) if subtitle.present?
          end
        end

        def avatar_is_hash_or_nil
          errors.add(:avatar, :invalid) unless avatar.nil? || avatar.is_a?(Hash)
        end
      end
    end
  end
end
