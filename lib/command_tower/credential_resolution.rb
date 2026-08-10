# frozen_string_literal: true

require "command_tower/credential_resolution/twilio_credentials"
require "command_tower/credential_resolution/smtp_credentials"
require "command_tower/credential_resolution/env_backend"
require "command_tower/credential_resolution/smtp_action_mailer_bridge"

module CommandTower
  # Provider-facing deployment credential normalization.
  # Hosts supply via config.credentials.*, custom resolver, and/or ENV.
  # Providers call resolve only — never branch on source.
  module CredentialResolution
    PROVIDERS = {
      twilio: TwilioCredentials,
      smtp: SmtpCredentials,
    }.freeze

    module_function

    def resolve(provider)
      key = normalize_provider!(provider)

      explicit = explicit_credentials(key)
      return explicit if explicit.available?

      custom = custom_resolver_credentials(key)
      return custom if custom&.available?

      env_credentials(key)
    end

    def normalize_provider!(provider)
      key = provider.to_sym
      raise ArgumentError, "Unknown credential provider: #{provider.inspect}" unless PROVIDERS.key?(key)

      key
    end
    private_class_method :normalize_provider!

    def explicit_credentials(key)
      case key
      when :twilio
        cfg = CommandTower.config.credentials.twilio
        TwilioCredentials.new(account_sid: cfg.account_sid, auth_token: cfg.auth_token)
      when :smtp
        cfg = CommandTower.config.credentials.smtp
        SmtpCredentials.new(user_name: cfg.user_name, password: cfg.password)
      end
    end
    private_class_method :explicit_credentials

    def custom_resolver_credentials(key)
      resolver = CommandTower.credential_resolver
      return nil if resolver.nil?

      unless resolver.respond_to?(:resolve)
        raise ArgumentError, "credential_resolver must respond to #resolve(provider)"
      end

      result = resolver.resolve(key)
      expected = PROVIDERS.fetch(key)
      unless result.is_a?(expected)
        raise TypeError, "credential_resolver for #{key.inspect} must return #{expected.name}"
      end

      result
    end
    private_class_method :custom_resolver_credentials

    def env_credentials(key)
      case key
      when :twilio then EnvBackend.twilio
      when :smtp then EnvBackend.smtp
      end
    end
    private_class_method :env_credentials
  end
end
