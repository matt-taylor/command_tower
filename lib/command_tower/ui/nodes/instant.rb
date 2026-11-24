# frozen_string_literal: true

require "time"
require "tzinfo"

module CommandTower
  module UI
    module Nodes
      # ActiveModel type for `at`: Time-like values become UTC ISO-8601 strings.
      class InstantAtType < ActiveModel::Type::Value
        private

        def cast_value(value)
          value.respond_to?(:utc) && value.respond_to?(:iso8601) ? value.utc.iso8601 : value
        end
      end

      # Wire type `time`. Named Instant so it never shadows ::Time inside Nodes.
      class Instant < Node
        TYPE = "time"
        FORMAT = %w[short long date time countdown].freeze
        LABEL = %w[auto always never].freeze
        # `zone: "user"` (or :user) means the recipient's zone, resolved at render time.
        USER_ZONE = "user"
        UTC_ISO8601 = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\z/

        field :at, InstantAtType.new
        field :zone, :string
        field :format, :string, default: "short"
        field :label, :string, default: "auto"
        field :variant, :string, default: "body"
        field :text_tone, :string, default: "primary"

        validate :at_is_utc_iso8601
        validate :zone_is_known
        validates :format, inclusion: { in: FORMAT }
        validates :label, inclusion: { in: LABEL }
        validates :variant, inclusion: { in: Tokens::VARIANT }
        validates :text_tone, inclusion: { in: Tokens::TEXT_TONE }

        private

        def at_is_utc_iso8601
          return errors.add(:at, :invalid) unless at.is_a?(String) && UTC_ISO8601.match?(at)

          Time.iso8601(at)
        rescue ArgumentError
          errors.add(:at, :invalid)
        end

        def zone_is_known
          return errors.add(:zone, :blank) if zone.blank?
          return if zone == USER_ZONE

          TZInfo::Timezone.get(zone)
        rescue TZInfo::InvalidTimezoneIdentifier
          errors.add(:zone, :invalid)
        end
      end
    end
  end
end
