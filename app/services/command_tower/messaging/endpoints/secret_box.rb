# frozen_string_literal: true

require "openssl"
require "base64"

module CommandTower
  module Messaging
    module Endpoints
      # Encrypts endpoint secrets at rest using ActiveSupport::MessageEncryptor.
      # Root secret → separately derived encryption keys per purpose (never shared with Fingerprinter).
      class SecretBox
        CURRENT_KEY_VERSION = 1
        ENCRYPT_PURPOSE = "command_tower.messaging.endpoints.encrypt.v1"
        PUSHOVER_USER_KEY_PURPOSE = "command_tower.messaging.endpoints.encrypt.pushover.user_key.v1"
        PUSHOVER_APPLICATION_TOKEN_PURPOSE =
          "command_tower.messaging.endpoints.encrypt.pushover.application_token.v1"
        CIPHER = "aes-256-gcm"

        class MissingSecretError < Error; end

        def self.encrypt(plaintext, purpose: ENCRYPT_PURPOSE)
          new(purpose:).encrypt(plaintext)
        end

        def self.decrypt(ciphertext, key_version: CURRENT_KEY_VERSION, purpose: ENCRYPT_PURPOSE)
          new(purpose:).decrypt(ciphertext, key_version:)
        end

        def self.key_version
          CURRENT_KEY_VERSION
        end

        def initialize(purpose: ENCRYPT_PURPOSE)
          @purpose = purpose.to_s
        end

        def encrypt(plaintext)
          payload = encryptor.encrypt_and_sign(plaintext.to_s)
          { ciphertext: payload, key_version: CURRENT_KEY_VERSION }
        end

        def decrypt(ciphertext, key_version: CURRENT_KEY_VERSION)
          raise ValidationError, "unsupported encryption_key_version: #{key_version}" unless key_version.to_i == CURRENT_KEY_VERSION

          encryptor.decrypt_and_verify(ciphertext.to_s)
        end

        private

        def encryptor
          @encryptor ||= ActiveSupport::MessageEncryptor.new(
            derived_encryption_key,
            cipher: CIPHER,
            serializer: JSON,
          )
        end

        def derived_encryption_key
          OpenSSL::HMAC.digest("SHA256", root_secret, @purpose)
        end

        def root_secret
          configured = ENV["COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET"].to_s
          if configured.empty?
            if production_like?
              raise MissingSecretError,
                    "COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET is required in production"
            end
            return "test-messaging-endpoint-secret-not-for-production"
          end

          configured
        end

        def production_like?
          env = if defined?(Rails) && Rails.respond_to?(:env)
            Rails.env
          else
            ENV["RAILS_ENV"] || ENV["RACK_ENV"]
          end
          env.to_s == "production"
        end
      end
    end
  end
end
