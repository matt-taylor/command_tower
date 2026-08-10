# frozen_string_literal: true

module FoundationProof
  class EchoService < CommandTower::Services::ApplicationService
    on_argument_validation :fail_early

    validate :message, is_a: String, required: true
    validate :limit, is_a: Integer, required: true

    def call
      context.message = message
      context.limit = limit
    end
  end
end
