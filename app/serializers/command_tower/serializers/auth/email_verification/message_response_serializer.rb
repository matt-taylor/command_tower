# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      module EmailVerification
        class MessageResponseSerializer
          def self.serialize(message:)
            { message: message }
          end
        end
      end
    end
  end
end
