# frozen_string_literal: true

require "digest"
require "json"

module CommandTower
  module Messaging
    module Accept
      class RequestNormalizer
        def self.fingerprint(**kwargs)
          new(**kwargs).fingerprint
        end

        def self.digest_host_event_identity(host_event_identity)
          Digest::SHA256.hexdigest(host_event_identity.to_s)
        end

        def initialize(
          title:,
          body:,
          metadata:,
          preference_state:,
          platform_enabled_channels:,
          message_overrides:
        )
          @title = title
          @body = body
          @metadata = metadata
          @preference_state = preference_state
          @platform_enabled_channels = platform_enabled_channels
          @message_overrides = message_overrides
        end

        def fingerprint
          Digest::SHA256.hexdigest(canonical_json)
        end

        def canonical_json
          JSON.generate(canonical_payload)
        end

        private

        def canonical_payload
          {
            "title" => @title.to_s,
            "body" => @body.to_s,
            "metadata" => normalize_value(@metadata),
            "preference_state" => normalize_value(@preference_state),
            "platform_enabled_channels" => normalize_channel_list(@platform_enabled_channels),
            "message_overrides" => normalize_overrides(@message_overrides),
          }
        end

        def normalize_overrides(raw)
          return nil if raw.nil?

          hash = raw.respond_to?(:to_h) ? raw.to_h : raise(ValidationError, "message_overrides must be hash-like")
          stringified = deep_stringify(hash)
          {
            "channels_add" => normalize_channel_list(stringified["channels_add"]),
            "channels_remove" => normalize_channel_list(stringified["channels_remove"]),
            "inbox" => stringified.key?("inbox") ? !!stringified["inbox"] : nil,
          }
        end

        def normalize_channel_list(value)
          return [] if value.nil?

          Array(value).map(&:to_s).uniq.sort
        end

        def normalize_value(value)
          case value
          when nil
            nil
          when Hash
            value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |v| normalize_value(v) }
          when Array
            # Prefer set-like sorting for channel lists; preserve nested structure recursively.
            value.map { |item| normalize_value(item) }
          else
            value
          end
        end

        def deep_stringify(value)
          case value
          when Hash
            value.to_h.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
          when Array
            value.map { |item| deep_stringify(item) }
          else
            value
          end
        end
      end
    end
  end
end
