# frozen_string_literal: true

module CommandTower
  module Errors
    module HomeNotices
      # A home-notice mutation could not read its controls or write: the client retries later.
      class UnavailableError < CommandTower::Errors::ApplicationError
        def code
          "home_notices_unavailable"
        end

        def message
          "Home notices are currently unavailable"
        end

        def log_level
          :error
        end
      end
    end
  end
end
