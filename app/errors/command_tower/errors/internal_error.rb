# frozen_string_literal: true

module CommandTower
  module Errors
    class InternalError < ApplicationError
      def code
        "internal_error"
      end

      def message
        "Internal error"
      end

      def log_level
        :error
      end
    end
  end
end
