# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Validators
        module Pushover
          module_function

          MIN_LENGTH = 8

          # Legacy single-address path retained for model/spec helpers that still
          # normalize a user key string — façade create/replace use credentials.
          def validate!(address)
            key = normalize_secret!(address, label: "pushover user key")
            Result.new(
              normalized_address: key,
              masked_display_value: mask_user_key(key),
            )
          end

          def validate_credentials!(credentials)
            hash = coerce_credentials!(credentials)
            user_key = normalize_secret!(hash[:user_key], label: "pushover user key")
            application_token = normalize_secret!(
              hash[:application_token],
              label: "pushover application token",
            )

            PushoverCredentialsResult.new(
              normalized_user_key: user_key,
              normalized_application_token: application_token,
              masked_display_value: mask_user_key(user_key),
              pair_fingerprint_material: "#{user_key}\n#{application_token}",
            )
          end

          def normalize_secret!(value, label:)
            secret = value.to_s.strip
            raise ValidationError, "#{label} must be present" if secret.empty?
            raise ValidationError, "#{label} is too short" if secret.length < MIN_LENGTH

            secret
          end

          def mask_user_key(key)
            if key.length >= 4
              "#{"•" * 8}#{key[-4, 4]}"
            else
              "configured"
            end
          end

          def coerce_credentials!(credentials)
            unless credentials.is_a?(Hash)
              raise ValidationError, "pushover credentials must be a Hash with user_key and application_token"
            end

            {
              user_key: credentials[:user_key] || credentials["user_key"],
              application_token: credentials[:application_token] || credentials["application_token"],
            }
          end
        end
      end
    end
  end
end
