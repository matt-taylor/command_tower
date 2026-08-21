# frozen_string_literal: true

module CommandTower
  module Serializers
    module Audit
      module Events
        class FilterOptionsSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(event_names:, subject_types:, attribution_modes:)
            {
              eventNames: Array(event_names).map { |entry| serialize_event_option(entry) },
              subjectTypes: Array(subject_types).map { |entry| serialize_subject_option(entry) },
              attributionModes: Array(attribution_modes).map { |entry| serialize_mode_option(entry) }
            }
          end

          def self.serialize_event_option(entry)
            {
              value: entry.fetch(:value),
              label: entry.fetch(:label),
              tags: Array(entry.fetch(:tags))
            }
          end
          private_class_method :serialize_event_option

          def self.serialize_subject_option(entry)
            {
              value: entry.fetch(:value),
              label: entry.fetch(:label)
            }
          end
          private_class_method :serialize_subject_option

          def self.serialize_mode_option(entry)
            {
              value: entry.fetch(:value),
              label: entry.fetch(:label)
            }
          end
          private_class_method :serialize_mode_option
        end
      end
    end
  end
end
