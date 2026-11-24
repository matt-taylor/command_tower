# frozen_string_literal: true

module CommandTower
  module Messaging
    module Unsubscribe
      # The signing boundary for one-click unsubscribe tokens (design D21). The key is derived from
      # `secret_key_base` through `Rails.application.message_verifier` unless
      # `config.messaging.compliance.unsubscribe_secret` overrides it. The token is signed, not
      # encrypted, and is bound to a purpose so no other signed value verifies as an unsubscribe token.
      module TokenVerifier
        VERIFIER_NAME = "command_tower/messaging/unsubscribe"
        PURPOSE = "unsubscribe"
        EXPIRES_IN = 90.days

        class << self
          def verifier
            secret = CommandTower.config.messaging.compliance.unsubscribe_secret.presence
            return Rails.application.message_verifier(VERIFIER_NAME) unless secret

            ActiveSupport::MessageVerifier.new(secret, serializer: JSON, url_safe: true)
          end
        end
      end
    end
  end
end
