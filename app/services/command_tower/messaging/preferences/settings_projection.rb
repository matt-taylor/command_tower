# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class SettingsProjection
        PUSH_CHANNEL = "push"

        URGENCY_LABELS = {
          "normal" => "Normal",
          "time_sensitive" => "Time Sensitive",
          "critical" => "Critical",
        }.freeze

        URGENCY_DESCRIPTIONS = {
          "normal" => "Delivered with the device’s normal notification behavior.",
          "time_sensitive" => "Asks the device to treat this alert as time sensitive.",
          "critical" =>
            "Highest declared urgency. Actual delivery behavior depends on the application and device capabilities.",
        }.freeze

        SettingEntry = Data.define(
          :key,
          :channel_key,
          :control,
          :label,
          :description,
          :editable,
          :effective,
          :options,
        )

        SingleSelectDefinition = Data.define(
          :key,
          :channel_key,
          :label,
          :description,
          :effective,
          :options,
        )

        def self.for_notification(declaration:, blocks:, destinations:)
          return [].freeze unless push_destination?(declaration, destinations)

          definitions = []
          urgency = blocks[:urgency]
          if urgency[:selectable]
            definitions << urgency_definition(urgency)
          end

          sound = blocks[:sound]
          if sound[:selectable]
            definitions << sound_definition(sound)
          end

          build(definitions)
        end

        def self.build(definitions)
          Array(definitions).filter_map do |definition|
            project_single_select(definition)
          end.freeze
        end

        def self.push_destination?(declaration, destinations)
          declaration.allowed_channels.include?(PUSH_CHANNEL) &&
            destinations.key?(PUSH_CHANNEL)
        end

        def self.urgency_definition(urgency_block)
          options =
            Array(urgency_block[:allowed]).map do |value|
              {
                value:,
                label: URGENCY_LABELS.fetch(value),
                description: URGENCY_DESCRIPTIONS.fetch(value),
              }.freeze
            end

          SingleSelectDefinition.new(
            key: "urgency",
            channel_key: PUSH_CHANNEL,
            label: "Urgency",
            description: nil,
            effective: urgency_block[:effective].to_s,
            options: options.freeze,
          )
        end

        def self.sound_definition(sound_block)
          options =
            Array(sound_block[:allowed]).map do |entry|
              id = entry[:id] || entry["id"]
              label = entry[:label] || entry["label"]
              { value: id, label:, description: nil }.freeze
            end

          SingleSelectDefinition.new(
            key: "sound",
            channel_key: PUSH_CHANNEL,
            label: "Sound",
            description: nil,
            effective: sound_block[:effective].to_s,
            options: options.freeze,
          )
        end

        def self.project_single_select(definition)
          SettingControls.validate_implemented!("single_select")

          SettingEntry.new(
            key: definition.key,
            channel_key: definition.channel_key,
            control: "single_select",
            label: definition.label,
            description: definition.description,
            editable: true,
            effective: definition.effective,
            options: definition.options,
          ).to_h.freeze
        end
        private_class_method :project_single_select
      end
    end
  end
end
