# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      MessageOverrides = Data.define(:channels_add, :channels_remove, :inbox) do
        FORBIDDEN_KEYS = %w[force_mandatory mandatory elevate_mandatory].freeze

        def self.normalize(raw)
          return nil if raw.nil?

          unless raw.respond_to?(:to_h)
            raise IllegalOverrideError, "message_overrides must be a hash-like object"
          end

          hash = raw.to_h.transform_keys(&:to_s)

          FORBIDDEN_KEYS.each do |key|
            if hash.key?(key)
              raise IllegalOverrideError, "message_overrides cannot include #{key}"
            end
          end

          channels_add = Array(hash["channels_add"]).map(&:to_s).freeze
          channels_remove = Array(hash["channels_remove"]).map(&:to_s).freeze
          inbox = hash.key?("inbox") ? !!hash["inbox"] : nil

          new(channels_add:, channels_remove:, inbox:).freeze
        end
      end
    end
  end
end
