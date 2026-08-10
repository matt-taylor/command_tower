# frozen_string_literal: true

require "command_tower/install/baseline"
require "command_tower/configuration/messaging/sms"
require "command_tower/configuration/messaging/pushover"

module CommandTower
  module Install
    # Friendly setup validation for host applications.
    # Returns structured findings; rake task prints remediation text.
    class Doctor
      INSECURE_JWT_DEFAULT = "Thi$IsASeccretIwi::CH&ang3"
      SUPPORTED_SMS_ADAPTERS = Configuration::Messaging::Sms::ADAPTERS
      SUPPORTED_PUSHOVER_ADAPTERS = Configuration::Messaging::Pushover::ADAPTERS
      Finding = Struct.new(:severity, :code, :message, :remediation, keyword_init: true)

      def initialize(host_root: Rails.root, config: CommandTower.config, env: Rails.env)
        @host_root = Pathname(host_root)
        @config = config
        @env = env.to_s
      end

      def run
        findings = []
        findings.concat(check_rails_version)
        findings.concat(check_engine_migrations)
        findings.concat(check_host_migrations)
        findings.concat(check_jwt_secret)
        findings.concat(check_session_secrets)
        findings.concat(check_messaging_adapters)
        findings
      end

      def ok?
        run.none? { |f| f.severity == :fail }
      end

      private

      attr_reader :host_root, :config, :env

      def check_rails_version
        version = Gem::Version.new(Rails::VERSION::STRING)
        min = Gem::Version.new("7.0.0")
        max = Gem::Version.new("9.0.0")
        if version >= min && version < max
          [Finding.new(
            severity: :pass,
            code: :rails_version,
            message: "Rails #{Rails::VERSION::STRING} is supported",
            remediation: nil
          )]
        else
          [Finding.new(
            severity: :fail,
            code: :rails_version,
            message: "Rails #{Rails::VERSION::STRING} is outside CommandTower's supported range",
            remediation: "Use Rails >= 7.0 and < 9.0 (see command_tower.gemspec)."
          )]
        end
      end

      def check_engine_migrations
        actual = Baseline.engine_migration_basenames
        expected = Baseline::ENGINE_MIGRATION_BASENAMES
        if actual == expected
          [Finding.new(
            severity: :pass,
            code: :engine_migrations,
            message: "Engine ships the #{expected.size}-migration baseline",
            remediation: nil
          )]
        else
          [Finding.new(
            severity: :fail,
            code: :engine_migrations,
            message: "Engine migration inventory does not match the expected baseline",
            remediation: "Expected #{expected.join(', ')}; found #{actual.join(', ') || '(none)'}."
          )]
        end
      end

      def check_host_migrations
        installed = Baseline.host_installed_migrations(host_root)
        expected_count = Baseline::ENGINE_MIGRATION_BASENAMES.size

        if installed.empty?
          [Finding.new(
            severity: :fail,
            code: :host_migrations,
            message: "No CommandTower migrations installed in the host",
            remediation: "Run `bin/rails command_tower:install` (or `command_tower:install:migrations`), then `bin/rails db:migrate`."
          )]
        elsif installed.size < expected_count
          [Finding.new(
            severity: :fail,
            code: :host_migrations,
            message: "Host has #{installed.size} CommandTower migration(s); expected at least #{expected_count}",
            remediation: "Run `bin/rails command_tower:install:migrations` after upgrading the gem, then `bin/rails db:migrate`."
          )]
        else
          [Finding.new(
            severity: :pass,
            code: :host_migrations,
            message: "Host has #{installed.size} installed CommandTower migration(s)",
            remediation: nil
          )]
        end
      end

      def check_jwt_secret
        secret = config.jwt.hmac_secret.to_s
        if secret.blank?
          return [Finding.new(
            severity: :fail,
            code: :jwt_secret,
            message: "JWT HMAC secret is blank",
            remediation: "Set `config.jwt.hmac_secret` (typically `ENV.fetch(\"SECRET_KEY_BASE\") { Rails.application.secret_key_base }`)."
          )]
        end

        if secret == INSECURE_JWT_DEFAULT
          severity = production? ? :fail : :warn
          return [Finding.new(
            severity: severity,
            code: :jwt_secret,
            message: "JWT HMAC secret is still the insecure CommandTower default",
            remediation: "Set `config.jwt.hmac_secret` from SECRET_KEY_BASE or Rails.application.secret_key_base before deploying."
          )]
        end

        [Finding.new(
          severity: :pass,
          code: :jwt_secret,
          message: "JWT HMAC secret is configured",
          remediation: nil
        )]
      end

      def check_session_secrets
        findings = []

        unless production_or_development_missing_ok?(config.signup_session.jwt_secret)
          findings << Finding.new(
            severity: production? ? :warn : :warn,
            code: :signup_session_secret,
            message: "Signup session JWT secret is blank",
            remediation: "Set `config.signup_session.jwt_secret` or ENV SIGNUP_SESSION_JWT_SECRET."
          )
        else
          findings << Finding.new(
            severity: :pass,
            code: :signup_session_secret,
            message: "Signup session JWT secret is configured",
            remediation: nil
          )
        end

        unless production_or_development_missing_ok?(config.password_recovery_session.jwt_secret)
          findings << Finding.new(
            severity: :warn,
            code: :password_recovery_secret,
            message: "Password recovery session JWT secret is blank",
            remediation: "Set `config.password_recovery_session.jwt_secret` or ENV PASSWORD_RECOVERY_SESSION_JWT_SECRET."
          )
        else
          findings << Finding.new(
            severity: :pass,
            code: :password_recovery_secret,
            message: "Password recovery session JWT secret is configured",
            remediation: nil
          )
        end

        findings
      end

      def check_messaging_adapters
        findings = []
        sms = config.messaging.sms.adapter.to_s
        pushover = config.messaging.pushover.adapter.to_s

        if sms.present? && !SUPPORTED_SMS_ADAPTERS.include?(sms)
          findings << Finding.new(
            severity: :warn,
            code: :sms_adapter,
            message: "Unsupported messaging SMS adapter #{sms.inspect}",
            remediation: "Use one of: #{SUPPORTED_SMS_ADAPTERS.join(', ')}."
          )
        else
          findings << Finding.new(
            severity: :pass,
            code: :sms_adapter,
            message: "Messaging SMS adapter is #{sms.presence || 'blank (defaults apply)'}",
            remediation: nil
          )
        end

        if pushover.present? && !SUPPORTED_PUSHOVER_ADAPTERS.include?(pushover)
          findings << Finding.new(
            severity: :warn,
            code: :pushover_adapter,
            message: "Unsupported messaging Pushover adapter #{pushover.inspect}",
            remediation: "Use one of: #{SUPPORTED_PUSHOVER_ADAPTERS.join(', ')}."
          )
        else
          findings << Finding.new(
            severity: :pass,
            code: :pushover_adapter,
            message: "Messaging Pushover adapter is #{pushover.presence || 'blank (defaults apply)'}",
            remediation: nil
          )
        end

        findings
      end

      def production_or_development_missing_ok?(secret)
        secret.to_s.present? || env == "test"
      end

      def production?
        env == "production"
      end
    end
  end
end
