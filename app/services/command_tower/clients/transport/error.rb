# frozen_string_literal: true

module CommandTower
  module Clients
    module Transport
      # Expected outbound transport failures (timeout, connection refused, etc.).
      # ClientBase maps these to failed ClientResult values — they are not framework defects.
      class Error < StandardError
        attr_reader :cause

        def initialize(message = nil, cause: nil)
          @cause = cause
          super(message)
        end
      end
    end
  end
end
