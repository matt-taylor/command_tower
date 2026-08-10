# frozen_string_literal: true

require "openssl"

module CommandTower
  module Messaging
    module Endpoints
      # HMAC fingerprint of Normalized Address. Uses a distinct derived key from SecretBox.
      module Fingerprinter
        module_function

        HMAC_PURPOSE = "command_tower.messaging.endpoints.fingerprint.v1"

        def fingerprint(normalized_address)
          digest = OpenSSL::HMAC.hexdigest("SHA256", derived_hmac_key, normalized_address.to_s)
          digest
        end

        def derived_hmac_key
          OpenSSL::HMAC.digest("SHA256", root_secret, HMAC_PURPOSE)
        end
        private_class_method :derived_hmac_key

        def root_secret
          configured = ENV["COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET"].to_s
          if configured.empty?
            if production_like?
              raise SecretBox::MissingSecretError,
                    "COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET is required in production"
            end
            return "test-messaging-endpoint-secret-not-for-production"
          end

          configured
        end
        private_class_method :root_secret

        def production_like?
          env = if defined?(Rails) && Rails.respond_to?(:env)
            Rails.env
          else
            ENV["RAILS_ENV"] || ENV["RACK_ENV"]
          end
          env.to_s == "production"
        end
        private_class_method :production_like?
      end
    end
  end
end
