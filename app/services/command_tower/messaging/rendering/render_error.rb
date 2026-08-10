# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      class RenderError < StandardError
        CODES = %w[recipient_missing render_failed].freeze

        attr_reader :code, :error_class

        def initialize(code:, error_class: nil)
          normalized = code.to_s
          unless CODES.include?(normalized)
            raise ArgumentError, "unsupported render error code: #{code.inspect}"
          end

          @code = normalized
          @error_class = error_class.nil? ? nil : error_class.to_s
          super(normalized)
        end
      end
    end
  end
end
