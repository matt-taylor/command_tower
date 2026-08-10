# frozen_string_literal: true

module FoundationProof
  class EchoSerializer < CommandTower::Serializers::ApplicationSerializer
    def self.serialize(message:, limit:)
      {
        message: message,
        limit: limit
      }
    end
  end
end
