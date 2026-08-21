# frozen_string_literal: true

module CommandTower
  module Errors
    class ContinuationExhaustedError < ApplicationError
      def code
        "continuation_exhausted"
      end

      def message
        attempt = details.is_a?(Hash) ? details[:attempt] : nil
        max_attempts = details.is_a?(Hash) ? details[:max_attempts] : nil
        if attempt && max_attempts
          "delayed continuation exhausted after attempt #{attempt} of #{max_attempts}"
        else
          "delayed continuation exhausted"
        end
      end

      def log_level
        :error
      end
    end
  end
end
