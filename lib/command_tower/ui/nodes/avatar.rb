# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Needs `src` (same https and host allowlist as image) or `initials`.
      # `alt` is required when `src` is present.
      class Avatar < Node
        TYPE = "avatar"

        field :src, :string
        field :initials, :string
        field :size, :string, default: "md"
        field :alt, :string

        validates :size, inclusion: { in: Tokens::AVATAR_SIZE }
        validates :initials, length: { maximum: 3 }, allow_nil: true
        validate :src_or_initials_present
        validate :src_is_allowed_image, if: -> { src.present? }
        validates :alt, presence: true, if: -> { src.present? }

        private

        def src_or_initials_present
          errors.add(:base, :src_or_initials_required) if src.blank? && initials.blank?
        end

        def src_is_allowed_image
          code = Hardening.image_src_code(src, hosts: CommandTower.config.ui.image_hosts)
          errors.add(:src, code) if code
        end
      end
    end
  end
end
