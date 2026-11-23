# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # `src` must be https on a host listed in config.ui.image_hosts (exact
      # match, fail closed). `alt` is required unless `decorative` is true
      # (council A12). `aspect` is width / height and is required (no server
      # measurement).
      class Image < Node
        TYPE = "image"
        FIT = %w[cover contain].freeze

        field :src, :string
        field :alt, :string
        field :decorative, :boolean, default: false
        field :aspect, :float
        field :animated, :boolean, default: false
        field :fit, :string, default: "cover"

        validate :src_is_allowed_image
        validate :alt_present_unless_decorative
        validates :aspect, numericality: { greater_than_or_equal_to: 0.1, less_than_or_equal_to: 10 }
        validates :fit, inclusion: { in: FIT }

        private

        def src_is_allowed_image
          return errors.add(:src, :blank) if src.blank?

          code = Hardening.image_src_code(src, hosts: CommandTower.config.ui.image_hosts)
          errors.add(:src, code) if code
        end

        def alt_present_unless_decorative
          errors.add(:alt, :blank) if alt.blank? && !decorative
        end
      end
    end
  end
end
