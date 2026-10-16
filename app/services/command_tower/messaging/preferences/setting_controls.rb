# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      module SettingControls
        IMPLEMENTED = %w[single_select].freeze
        RESERVED = %w[boolean multi_select read_only].freeze

        class UnsupportedControlError < StandardError; end

        def self.validate_implemented!(control)
          normalized = control.to_s
          if RESERVED.include?(normalized) && !IMPLEMENTED.include?(normalized)
            raise UnsupportedControlError,
                  "setting control #{normalized.inspect} is reserved and not implemented"
          end
          return if IMPLEMENTED.include?(normalized)

          raise UnsupportedControlError, "unknown setting control: #{normalized.inspect}"
        end
      end
    end
  end
end
