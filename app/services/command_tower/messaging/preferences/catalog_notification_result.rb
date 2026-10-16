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
        :urgency,
        :sound,
        :channel_catalog,
        :destinations,
        :corrections,
        :settings,
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
          stored_override_present:,
          urgency:,
          sound:,
          channel_catalog: [],
          destinations: {},
          corrections: nil,
          settings: []
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
            urgency: freeze_block(urgency),
            sound: freeze_block(sound),
            channel_catalog: freeze_channel_catalog(channel_catalog),
            destinations: freeze_destinations(destinations),
            corrections: freeze_corrections(corrections),
            settings: freeze_settings(settings),
          ).freeze
        end

        def self.freeze_settings(settings)
          Array(settings).map(&:freeze).freeze
        end
        private_class_method :freeze_settings

        def self.freeze_channel_catalog(entries)
          Array(entries).map(&:freeze).freeze
        end
        private_class_method :freeze_channel_catalog

        def self.freeze_destinations(destinations)
          destinations.to_h.transform_keys(&:to_s).transform_values(&:freeze).freeze
        end
        private_class_method :freeze_destinations

        def self.freeze_corrections(corrections)
          return nil if corrections.nil?

          Array(corrections).map(&:freeze).freeze
        end
        private_class_method :freeze_corrections

        def self.freeze_block(block)
          hash = block.to_h
          allowed = hash[:allowed]
          frozen_allowed =
            if allowed.is_a?(Array) && allowed.first.is_a?(Hash)
              allowed.map { |entry| entry.to_h.transform_keys(&:to_sym).freeze }.freeze
            else
              Array(allowed).map(&:to_s).freeze
            end

          {
            default: hash[:default].to_s,
            allowed: frozen_allowed,
            selectable: !!hash[:selectable],
            effective: hash[:effective].to_s,
          }.freeze
        end
        private_class_method :freeze_block
      end
    end
  end
end
