# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class PasswordCheckSerializer
        def self.serialize(valid:, failures:, message:)
          {
            valid: valid,
            failures: failures.map(&:to_s),
            message: message
          }
        end
      end
    end
  end
end
