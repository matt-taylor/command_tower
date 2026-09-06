# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Validators
        module Push
          module_function

          # Expo push token forms used by expo-notifications / Expo Push API.
          EXPO_TOKEN = /\A(ExponentPushToken|ExpoPushToken)\[[^\]]+\]\z/

          def validate!(address)
            token = address.to_s.strip
            raise ValidationError, "push token must be present" if token.empty?
            raise ValidationError, "push token is too short" if token.length < 8
            unless token.match?(EXPO_TOKEN)
              raise ValidationError, "push token must be an Expo push token (ExponentPushToken[...] or ExpoPushToken[...])"
            end

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
