# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      # Resolves what Accept stores for a definition-backed type: the channel slots, the stored
      # title and body, the render zone and the metadata version. Pure apart from one user lookup
      # for the zone. It never raises for an expected failure and never reads `strict_definitions`:
      # it returns a {Resolution} and the caller decides whether a failure fails the request or is
      # logged and degraded. Failures carry codes and attribute names only, never metadata values.
      class ResolveCommunicationSlots
        FAILURE_METADATA_SCHEMA = "metadata_schema_violation"
        FAILURE_SLOTS = "slots_unbuildable"
        FAILURE_HEADLINE = "headline_missing"

        # `failure_code` is nil on success. `FAILURE_METADATA_SCHEMA` means the slots, title and
        # body are still usable (the request may degrade); any other code means they are not.
        Resolution = Data.define(
          :slots, :title, :body, :render_zone, :metadata_version, :failure_code, :schema_errors
        ) do
          def success?
            failure_code.nil?
          end

          def failure?
            !success?
          end

          def degradable?
            failure_code == FAILURE_METADATA_SCHEMA
          end

          # Attribute names and the code only.
          def failure_message
            detail = schema_errors.any? ? " (attributes: #{schema_errors.join(', ')})" : ""
            "#{failure_code}#{detail}"
          end
        end

        def self.call(...)
          new(...).call
        end

        # @param definition [Class] a MessageDefinition subclass
        def initialize(notification_type_key:, definition:, metadata:, recipient_id:)
          @notification_type_key = notification_type_key.to_s
          @definition = definition
          @metadata = (metadata || {}).to_h.transform_keys(&:to_s)
          @recipient_id = recipient_id
        end

        def call
          @schema_errors = definition.metadata_schema.schema_errors(@metadata)
          slots = build_slots
          return resolution(FAILURE_SLOTS) if slots.nil?
          return resolution(FAILURE_HEADLINE) if slots[:headline].to_s.strip.empty?

          resolution(@schema_errors.any? ? FAILURE_METADATA_SCHEMA : nil, slots)
        end

        private

        attr_reader :definition

        # `slots` (symbol-keyed) is given only when title, body and slots are usable.
        def resolution(failure_code, slots = nil)
          Resolution.new(
            slots: slots&.transform_keys(&:to_s),
            title: slots && slots[:headline].to_s,
            body: slots && (slots[:push_body].presence || slots[:headline].to_s),
            render_zone:,
            metadata_version: definition.metadata_version,
            failure_code:,
            schema_errors: @schema_errors
          )
        end

        # nil when the definition's `slots` raised; the error is never surfaced (it may quote
        # metadata).
        def build_slots
          Definitions::DocumentBuilder.slots(definition: definition.new, context:)
        rescue StandardError
          nil
        end

        def context
          Definitions::RenderContext.new(
            notification_type_key: @notification_type_key,
            metadata: @metadata,
            metadata_version: definition.metadata_version,
            slots: nil,
            render_zone:
          )
        end

        # The recipient's last known zone when it is a TZInfo identifier, else the definition's
        # default zone, else the platform UI default.
        def render_zone
          @render_zone ||= valid_zone(recipient_zone) ||
                           valid_zone(definition.default_zone) ||
                           CommandTower.config.ui.default_zone
        end

        def recipient_zone
          User.where(id: @recipient_id).pick(:last_known_timezone)
        end

        def valid_zone(zone)
          zone if zone.present? && TZInfo::Timezone.all_identifiers.include?(zone)
        end
      end
    end
  end
end
