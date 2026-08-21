require "command_tower/error"
require "command_tower/current"
require "command_tower/execution"
require "command_tower/events"
require "command_tower/audit"
require "command_tower/impersonation/activity_declaration"
require "command_tower/impersonation/apply_overlay"
require "command_tower/impersonation/establish_identity"
require "command_tower/admin_workspace"
require "command_tower/admin_scope"
require "command_tower/logging/lifecycle_declaration"
require "command_tower/logging/projection"
require "command_tower/logging/subscriber"

require "command_tower/version"
require "command_tower/engine"
require "command_tower/configuration/config"
require "command_tower/install/baseline"
require "command_tower/install/doctor"
require "command_tower/credential_resolution"
require "command_tower/jwt/authorization_helper"
require "command_tower/jwt/csrf_helper"
require "command_tower/password_recovery/authorization_helper"
require "command_tower/redis_connection"
require "command_tower/signup/authorization_helper"

module CommandTower
  def self.config
    @config ||= Configuration::Config.new
  end

  def self.configure
    yield(config)
    CredentialResolution::SmtpActionMailerBridge.apply!
  end

  def self.config=(configuration)
    raise ArgumentError, "Expected Configuration::Config. Given #{configuration.class}" unless Configuration::Config === configuration

    @config = configuration
  end

  # Optional custom credential resolver (#resolve(provider) → typed credentials).
  # Precedence: config.credentials.* → credential_resolver → ENV.
  def self.credential_resolver
    @credential_resolver
  end

  def self.credential_resolver=(resolver)
    @credential_resolver = resolver
  end

  def self.app_name
    Proc === config.app.app_name ? config.app.app_name.() : config.app.app_name
  end

  def self.app_name_for_comms
    Proc === config.app.communication_name ? config.app.communication_name.() : config.app.communication_name
  end

  def self.default_app_name
    ::Rails.application.class.module_parent_name
  end
end
