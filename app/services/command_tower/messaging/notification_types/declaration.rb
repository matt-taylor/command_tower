# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      Declaration = Data.define(
        :key,
        :allowed_channels,
        :default_channels,
        :inbox_available,
        :user_configurable,
        :mandatory,
        :default_preference_state,
        :label,
        :category_key,
        :category_label,
        :category_order,
        :type_order,
        :settings_visible,
        :description,
        :priority,
        :retention,
        :delivery_status_visible,
        :host_ownership,
      ) do
        def self.build(
          key:,
          allowed_channels:,
          default_channels:,
          inbox_available:,
          user_configurable:,
          mandatory:,
          default_preference_state:,
          label:,
          category_key:,
          category_label:,
          category_order:,
          type_order:,
          settings_visible: true,
          description: nil,
          priority: nil,
          retention: nil,
          delivery_status_visible: nil,
          host_ownership: nil
        )
          new(
            key: key.nil? ? nil : key.to_s,
            allowed_channels: freeze_channel_list(allowed_channels),
            default_channels: freeze_channel_list(default_channels),
            inbox_available: !!inbox_available,
            user_configurable: !!user_configurable,
            mandatory: !!mandatory,
            default_preference_state: freeze_preference_state(default_preference_state),
            label: label.nil? ? nil : label.to_s,
            category_key: category_key.nil? ? nil : category_key.to_s,
            category_label: category_label.nil? ? nil : category_label.to_s,
            category_order:,
            type_order:,
            settings_visible: !!settings_visible,
            description:,
            priority:,
            retention:,
            delivery_status_visible:,
            host_ownership:,
          ).freeze
        end

        def self.freeze_channel_list(channels)
          return nil if channels.nil?

          Array(channels).map { |channel| channel.to_s }.freeze
        end
        private_class_method :freeze_channel_list

        def self.freeze_preference_state(state)
          return nil if state.nil?

          hash = state.to_h.transform_keys(&:to_s)
          channels = hash["channels"]
          frozen_channels =
            if channels.nil?
              nil
            else
              channels.to_h.transform_keys(&:to_s).transform_values { |value| !!value }.freeze
            end

          {
            "channels" => frozen_channels,
            "inbox" => hash.key?("inbox") ? !!hash["inbox"] : nil,
          }.freeze
        end
        private_class_method :freeze_preference_state
      end
    end
  end
end
