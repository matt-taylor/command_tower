# frozen_string_literal: true

module CommandTower
  module Errors
    class ValidationError < ApplicationError
      def code
        "validation_failed"
      end

      def message
        "Validation failed"
      end
    end
  end
end
