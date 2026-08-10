# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      class DeclarationValidator
        # Lowercase alphanumeric segments separated by "." or "_".
        # Compatible with existing keys such as "hello_world" and "booking.success".
        IDENTIFIER_FORMAT = /\A[a-z][a-z0-9]*(?:[._][a-z][a-z0-9]*)*\z/

        def self.validate!(declaration)
          errors = validate(declaration)
          return if errors.empty?

          raise InvalidDeclarationError, errors.join("; ")
        end

        def self.validate(declaration)
          errors = []

          if declaration.nil?
            errors << "declaration is required"
            return errors
          end

          validate_identifier_field(errors, declaration.key, field: "key", allow_blank_message: "key must be present")
          validate_non_blank_string(errors, declaration.label, field: "label")
          validate_identifier_field(
            errors,
            declaration.category_key,
            field: "category_key",
            allow_blank_message: "category_key must be present",
          )
          validate_non_blank_string(errors, declaration.category_label, field: "category_label")
          validate_non_negative_integer(errors, declaration.category_order, field: "category_order")
          validate_non_negative_integer(errors, declaration.type_order, field: "type_order")

          if declaration.allowed_channels.nil?
            errors << "allowed_channels is required"
          elsif !declaration.allowed_channels.is_a?(Array)
            errors << "allowed_channels must be an array"
          end

          if declaration.default_channels.nil?
            errors << "default_channels is required"
          elsif !declaration.default_channels.is_a?(Array)
            errors << "default_channels must be an array"
          end

          if declaration.allowed_channels.is_a?(Array)
            validate_channel_list(errors, declaration.allowed_channels, field: "allowed_channels")
          end

          if declaration.default_channels.is_a?(Array)
            validate_channel_list(errors, declaration.default_channels, field: "default_channels")
          end

          if declaration.allowed_channels.is_a?(Array) && declaration.default_channels.is_a?(Array)
            extras = declaration.default_channels - declaration.allowed_channels
            if extras.any?
              errors << "default_channels must be a subset of allowed_channels (extras: #{extras.join(', ')})"
            end
          end

          if declaration.default_preference_state.nil?
            errors << "default_preference_state is required"
          elsif !declaration.default_preference_state.is_a?(Hash)
            errors << "default_preference_state must be a hash"
          end

          unless [true, false].include?(declaration.settings_visible)
            errors << "settings_visible must be a boolean"
          end

          errors
        end

        def self.validate_category_consistency!(declaration, peers:)
          errors = category_consistency_errors(declaration, peers:)
          return if errors.empty?

          raise InvalidDeclarationError, errors.join("; ")
        end

        def self.category_consistency_errors(declaration, peers:)
          return [] if declaration.nil? || declaration.category_key.nil? || declaration.category_key.strip.empty?

          peers = Array(peers)
          conflicting = peers.select { |peer| peer.category_key == declaration.category_key }
          return [] if conflicting.empty?

          errors = []
          peer = conflicting.first

          if peer.category_label != declaration.category_label
            errors << "category_key #{declaration.category_key.inspect} has conflicting category_label " \
                      "(#{declaration.category_label.inspect} vs #{peer.category_label.inspect})"
          end

          if peer.category_order != declaration.category_order
            errors << "category_key #{declaration.category_key.inspect} has conflicting category_order " \
                      "(#{declaration.category_order.inspect} vs #{peer.category_order.inspect})"
          end

          errors
        end

        def self.validate_identifier_field(errors, value, field:, allow_blank_message:)
          if value.nil? || !value.is_a?(String) || value.strip.empty?
            errors << allow_blank_message
            return
          end

          return if value.match?(IDENTIFIER_FORMAT)

          errors << "#{field} must match the established notification identifier format"
        end
        private_class_method :validate_identifier_field

        def self.validate_non_blank_string(errors, value, field:)
          if value.nil? || !value.is_a?(String) || value.strip.empty?
            errors << "#{field} must be present"
          end
        end
        private_class_method :validate_non_blank_string

        def self.validate_non_negative_integer(errors, value, field:)
          unless value.is_a?(Integer) && value >= 0
            errors << "#{field} must be a non-negative Integer"
          end
        end
        private_class_method :validate_non_negative_integer

        def self.validate_channel_list(errors, channels, field:)
          channels.each do |channel|
            key = channel.to_s
            unless Channels.known?(key)
              errors << "#{field} contains unknown channel: #{key.inspect}"
              next
            end

            definition = Channels.fetch(key)
            next if definition.external?

            errors << "#{field} contains non-external channel: #{key.inspect}"
          end
        end
        private_class_method :validate_channel_list
      end
    end
  end
end
