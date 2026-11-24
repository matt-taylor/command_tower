# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      # Seal-time checks for declarations that name a `MessageDefinition` (`message:`) or still use
      # `inbox_document_composer`. Runs only from `Registry#seal`, so the class name is constantized
      # after host autoloading is ready and never while hosts are still registering. Errors carry
      # the type key, class names and slot names only; never metadata values.
      class MessageDefinitionChecks
        # Slot each channel needs before its content can be delivered. `inbox` renders from the
        # inbox document, not from a slot.
        CHANNEL_SLOTS = {
          "email" => :subject,
          "push" => :push_body,
          "sms" => :sms_body,
          "pushover" => :pushover_message
        }.freeze

        TYPE_TEMPLATE_ROOT = "command_tower/messaging/rendering"
        TYPE_KEY_FORMAT = /\A[a-z0-9_]+\z/

        class << self
          # Raises InvalidDeclarationError for the first invalid declaration, then logs one
          # deprecation line for every type still on `inbox_document_composer`.
          def validate!(declarations)
            declarations.each do |declaration|
              found = errors(declaration)
              raise InvalidDeclarationError, "#{declaration.key}: #{found.join('; ')}" if found.any?
            end
            log_composer_deprecation(declarations)
            Rendering::UnsubscribeHeaders.warn_when_unconfigured(declarations.select(&:message))
          end

          # @return [Array<String>]
          def errors(declaration)
            new(declaration).errors
          end

          private

          def log_composer_deprecation(declarations)
            keys = declarations.select(&:inbox_document_composer).map(&:key)
            return if keys.empty?

            Rails.logger.warn(
              "[command_tower] DEPRECATION: inbox_document_composer is deprecated in favor of message: " \
              "(types: #{keys.join(', ')})"
            )
          end
        end

        def initialize(declaration)
          @declaration = declaration
        end

        def errors
          return [] if @declaration.message.nil?
          return ["message: and inbox_document_composer are mutually exclusive"] if @declaration.inbox_document_composer
          return ["message #{@declaration.message.inspect} must name a MessageDefinition subclass"] unless definition

          per_type_template_errors + zone_errors + version_errors + promotional_errors + fixture_errors
        end

        private

        def definition
          return @definition if defined?(@definition)

          klass = @declaration.message.safe_constantize
          @definition = klass if klass.is_a?(Class) && klass < MessageDefinition
        end

        def per_type_template_errors
          key = @declaration.key.to_s
          return [] unless key.match?(TYPE_KEY_FORMAT)

          dirs = [Rails.root, CommandTower::Engine.root].map { |root| root.join("app/views", TYPE_TEMPLATE_ROOT, key) }
          return [] unless dirs.any? { |dir| Dir.exist?(dir) && Dir.children(dir).any? }

          ["message definition types must not have per-type ERB under #{TYPE_TEMPLATE_ROOT}/#{key}"]
        end

        def zone_errors
          zone = definition.default_zone
          return [] if zone.nil? || TZInfo::Timezone.all_identifiers.include?(zone)

          ["default_zone #{zone.inspect} is not a TZInfo identifier"]
        end

        def version_errors
          version = definition.metadata_version
          return [] if version.is_a?(Integer) && version.positive?

          ["metadata_version must be a positive Integer"]
        end

        def promotional_errors
          return [] unless definition.promotional?
          return [] if CommandTower.config.messaging.compliance.postal_address.present?

          ["promotional messages require config.messaging.compliance.postal_address"]
        end

        def fixture_errors
          first = definition.fixtures.values.first
          return ["at least one fixture is required"] if first.nil?

          slot_errors(first)
        end

        # The first fixture is the representative one: it must produce a headline and a slot for
        # every allowed channel.
        def slot_errors(metadata)
          slots = build_slots(metadata)
          return ["first fixture slots could not be built (#{slots})"] if slots.is_a?(String)

          required = [:headline] + @declaration.allowed_channels.filter_map { |channel| CHANNEL_SLOTS[channel] }
          missing = required.select { |slot| slots[slot].to_s.strip.empty? }
          missing.empty? ? [] : ["first fixture slots are missing: #{missing.join(', ')}"]
        end

        # @return [Hash{Symbol => String}, String] the slots, or the error class name when the
        #   definition's `slots` raised
        def build_slots(metadata)
          Definitions::DocumentBuilder.slots(definition: definition.new, context: context(metadata))
        rescue StandardError => e
          e.class.name
        end

        def context(metadata)
          Definitions::RenderContext.new(
            notification_type_key: @declaration.key,
            metadata:,
            metadata_version: definition.metadata_version,
            slots: nil,
            render_zone: definition.default_zone.presence || CommandTower.config.ui.default_zone
          )
        end
      end
    end
  end
end
