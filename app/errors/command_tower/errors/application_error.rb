# frozen_string_literal: true

module CommandTower
  module Errors
    class ApplicationError < StandardError
      attr_reader :details, :cause

      def initialize(details: nil, cause: nil)
        @details = details
        @cause = cause
        super()
      end

      def code
        raise NotImplementedError
      end

      def retryable?
        false
      end

      def log_level
        :info
      end
    end
  end
end
