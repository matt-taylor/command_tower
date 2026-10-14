# frozen_string_literal: true

module CommandTower
  module Messaging
    # Registered push sounds. The engine owns System Default, a logical id that needs no
    # bundled native asset. Hosts append custom entries through
    # `config.messaging.sounds` (`{ id:, label:, asset: }`); `asset` is the native file
    # reference. Whether the file is physically bundled is verified later (IOS), not here.
    module SoundCatalog
      module_function

      ID_FORMAT = /\A[a-z][a-z0-9_]*\z/
      # iOS plays a custom push sound only for a bundled file name with one of these extensions.
      ASSET_EXTENSIONS = %w[.wav .aiff .caf].freeze
      SYSTEM_DEFAULT = { id: "default", label: "System Default", asset: nil }.freeze

      def entries
        [SYSTEM_DEFAULT] + host_entries.grep(Hash).map { |entry| entry.transform_keys(&:to_sym).freeze }
      end

      def ids
        entries.pluck(:id)
      end

      def fetch(id)
        entries.find { |entry| entry[:id] == id.to_s }
      end

      # Messages for an invalid host catalog; empty when valid. Registry seal raises on them.
      def validation_errors
        errors = []
        seen = [SYSTEM_DEFAULT[:id]]

        host_entries.each_with_index do |entry, index|
          label = "sounds[#{index}]"
          unless entry.is_a?(Hash)
            errors << "#{label} must be a hash"
            next
          end

          entry = entry.transform_keys(&:to_sym)
          errors.concat(entry_errors(entry, label:, seen:))
          seen << entry[:id]
        end

        errors
      end

      def host_entries
        Array(CommandTower.config.messaging.sounds)
      end
      private_class_method :host_entries

      def entry_errors(entry, label:, seen:)
        id = entry[:id]
        errors = []

        if !id.is_a?(String) || !id.match?(ID_FORMAT)
          errors << "#{label} id must match #{ID_FORMAT.inspect}"
        elsif seen.include?(id)
          reason = id == SYSTEM_DEFAULT[:id] ? "reserved for System Default" : "duplicated"
          errors << "#{label} id #{id.inspect} is #{reason}"
        end

        errors << "#{label} label must be present" unless present_string?(entry[:label])
        errors.concat(asset_errors(entry[:asset], label:))
        errors
      end
      private_class_method :entry_errors

      def asset_errors(asset, label:)
        return ["#{label} asset must be present"] unless present_string?(asset)
        return [] if ASSET_EXTENSIONS.include?(File.extname(asset).downcase)

        ["#{label} asset must end in #{ASSET_EXTENSIONS.join(', ')}"]
      end
      private_class_method :asset_errors

      def present_string?(value)
        value.is_a?(String) && !value.strip.empty?
      end
      private_class_method :present_string?
    end
  end
end
