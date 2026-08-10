# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      PreferenceState = Data.define(:channels, :inbox) do
        def self.normalize(raw)
          return nil if raw.nil?

          unless raw.respond_to?(:to_h)
            raise InvalidPreferenceStateError, "preference_state must be a hash-like object"
          end

          hash = raw.to_h.transform_keys(&:to_s)

          if hash.empty?
            return nil
          end

          channels_raw = hash["channels"]
          channels =
            if channels_raw.nil?
              {}.freeze
            else
              unless channels_raw.respond_to?(:to_h)
                raise InvalidPreferenceStateError, "preference_state channels must be a hash-like object"
              end

              channels_raw.to_h.transform_keys(&:to_s).transform_values { |value| !!value }.freeze
            end

          inbox = hash.key?("inbox") ? !!hash["inbox"] : nil

          new(channels:, inbox:).freeze
        end

        def self.from_declaration_default(default_preference_state)
          normalize(default_preference_state) || new(channels: {}.freeze, inbox: nil).freeze
        end

        def merge_over(base)
          merged_channels = base.channels.merge(channels)
          merged_inbox = inbox.nil? ? base.inbox : inbox
          self.class.new(channels: merged_channels.freeze, inbox: merged_inbox).freeze
        end

        def channel_enabled?(channel_key, default: true)
          return default unless channels.key?(channel_key)

          channels.fetch(channel_key)
        end

        def to_raw_hash
          hash = { "channels" => channels.to_h }
          hash["inbox"] = inbox unless inbox.nil?
          hash
        end
      end
    end
  end
end
