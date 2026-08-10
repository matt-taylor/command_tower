# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      module Validators
        Result = Data.define(:normalized_address, :masked_display_value)
        PushoverCredentialsResult = Data.define(
          :normalized_user_key,
          :normalized_application_token,
          :masked_display_value,
          :pair_fingerprint_material,
        )

        module_function

        def for(channel_key)
          case channel_key.to_s
          when "push" then Push
          when "pushover" then Pushover
          else
            raise ValidationError, "no validator for channel: #{channel_key.inspect}"
          end
        end

        def validate!(channel_key:, address:)
          self.for(channel_key).validate!(address)
        end

        def validate_pushover_credentials!(credentials)
          Pushover.validate_credentials!(credentials)
        end
      end
    end
  end
end
