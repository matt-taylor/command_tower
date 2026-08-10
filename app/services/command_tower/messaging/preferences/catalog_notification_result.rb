# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      CatalogNotificationResult = Data.define(
        :key,
        :label,
        :description,
        :order,
        :configurable,
        :mandatory,
        :inbox_available,
        :allowed_channels,
        :available_channels,
        :inbox_enabled,
        :channels,
        :stored_override_present,
      ) do
        def self.build(
          key:,
          label:,
          description:,
          order:,
          configurable:,
          mandatory:,
          inbox_available:,
          allowed_channels:,
          available_channels:,
          inbox_enabled:,
          channels:,
          stored_override_present:
        )
          frozen_channels =
            channels.to_h.transform_keys(&:to_s).transform_values { |value| !!value }.freeze

          new(
            key: key.to_s,
            label: label.to_s,
            description:,
            order: Integer(order),
            configurable: !!configurable,
            mandatory: !!mandatory,
            inbox_available: !!inbox_available,
            allowed_channels: Array(allowed_channels).map(&:to_s).freeze,
            available_channels: Array(available_channels).map(&:to_s).freeze,
            inbox_enabled: !!inbox_enabled,
            channels: frozen_channels,
            stored_override_present: !!stored_override_present,
          ).freeze
        end
      end
    end
  end
end
