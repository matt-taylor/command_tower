# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      class IdempotencyConflictError < Error; end
    end
  end
end
