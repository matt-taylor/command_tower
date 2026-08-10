# frozen_string_literal: true

module CommandTower
  module Errors
    class ForbiddenError < ApplicationError
      def code
        "forbidden"
      end

      def message
        "Forbidden"
      end

      def log_level
        :warn
      end
    end
  end
end
