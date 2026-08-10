# frozen_string_literal: true

module CommandTower
  module Errors
    class UnauthorizedError < ApplicationError
      def code
        "unauthorized"
      end

      def message
        "Unauthorized"
      end

      def log_level
        :warn
      end
    end
  end
end
