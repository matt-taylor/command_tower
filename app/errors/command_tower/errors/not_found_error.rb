# frozen_string_literal: true

module CommandTower
  module Errors
    class NotFoundError < ApplicationError
      def code
        "not_found"
      end

      def message
        "Not found"
      end

      def log_level
        :info
      end
    end
  end
end
