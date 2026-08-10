# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Validators
        module Push
          module_function

          def validate!(address)
            token = address.to_s.strip
            raise ValidationError, "push token must be present" if token.empty?
            raise ValidationError, "push token is too short" if token.length < 8

            Result.new(
              normalized_address: token,
              masked_display_value: "Device registered",
            )
          end
        end
      end
    end
  end
end
