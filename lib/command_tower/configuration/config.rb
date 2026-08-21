# frozen_string_literal: true

require "singleton"
require "class_composer"
require "command_tower/configuration/admin/config"
require "command_tower/configuration/admin_scope/config"
require "command_tower/configuration/application/config"
require "command_tower/configuration/authorization/config"
require "command_tower/configuration/base"
require "command_tower/configuration/credentials/config"
require "command_tower/configuration/email/config"
require "command_tower/configuration/identity/config"
require "command_tower/configuration/impersonation/config"
require "command_tower/configuration/jwt/config"
require "command_tower/configuration/jwt/cookie/config"
require "command_tower/configuration/login/config"
require "command_tower/configuration/messaging/config"
require "command_tower/configuration/otp/config"
require "command_tower/configuration/pagination/config"
require "command_tower/configuration/password_recovery_session/config"
require "command_tower/configuration/registry/config"
require "command_tower/configuration/signup_session/config"
require "command_tower/configuration/user/config"
require "command_tower/configuration/username/config"

module CommandTower
  module Configuration
    class Config < ::CommandTower::Configuration::Base
      include ClassComposer::Generator

      add_composer :delete_secret_after_invalid,
        desc: "Remove Secret after it is found as invalid",
        allowed: [TrueClass, FalseClass],
        default: true

      add_composer :jwt,
        desc: "JWT is the basis for Authorization and Authentication for this Engine. HMAC is the only support algorithm",
        allowed: Configuration::Jwt::Config,
        default: Configuration::Jwt::Config.new

      add_composer :login,
        desc: "Definition of Login Strategies.",
        allowed: Configuration::Login::Config,
        default: Configuration::Login::Config.new

      add_composer :email,
        desc: "Email configuration for the app sending Native Rails emails via ActiveMailer. Config changed here will update the Rails Configuration as well",
        allowed: Configuration::Email::Config,
        default: Configuration::Email::Config.new

      add_composer :credentials,
        desc: "Deployment provider credentials (typed per provider under config.credentials.<provider>). Consumed by Credential Resolution. Not provider behavior configuration.",
        allowed: Configuration::Credentials::Config,
        default: Configuration::Credentials::Config.new

      add_composer :username,
        desc: "Username configuration for the app",
        allowed: Configuration::Username::Config,
        default: Configuration::Username::Config.new

      add_composer :application,
        desc: "General configurations for the application. Primarily include application specific names, URL's, etc",
        allowed: Configuration::Application::Config,
        default: Configuration::Application::Config.new

      # allow shorthand to be used
      alias_method :app, :application

      add_composer :authorization,
        desc: "Authorization via rbac configurations",
        allowed: Configuration::Authorization::Config,
        default: Configuration::Authorization::Config.new

      add_composer :user,
        desc: "User configuration for the app. Includes what to display and what attributes can be changed",
        allowed: Configuration::User::Config,
        default: Configuration::User::Config.new

      add_composer :identity,
        desc: "Identity-owned capabilities (phone verification OTP, etc.)",
        allowed: Configuration::Identity::Config,
        default: Configuration::Identity::Config.new

      add_composer :impersonation,
        desc: "Impersonation session idle and absolute timeouts",
        allowed: Configuration::Impersonation::Config,
        default: Configuration::Impersonation::Config.new

      add_composer :messaging,
        desc: "Messaging delivery configuration (notification SMS, etc.). Separate from Identity OTP.",
        allowed: Configuration::Messaging::Config,
        default: Configuration::Messaging::Config.new

      add_composer :admin,
        desc: "Admin configuration for the app",
        allowed: Configuration::Admin::Config,
        default: Configuration::Admin::Config.new

      add_composer :admin_scope,
        desc: "Host hooks for optional Admin resource scoping (options, validation, narrowing)",
        allowed: Configuration::AdminScope::Config,
        dynamic_default: ->(_) { Configuration::AdminScope::Config.new },
        default_shown: "Configuration::AdminScope::Config.new"

      add_composer :pagination,
        desc: "Pagination configuration for the app",
        allowed: Configuration::Pagination::Config,
        default: Configuration::Pagination::Config.new

      add_composer :registry,
        desc: "Host and platform registrations expressed as configuration (not a plugin API)",
        allowed: Configuration::Registry::Config,
        dynamic_default: ->(_) { Configuration::Registry::Config.new },
        default_shown: "Configuration::Registry::Config.new"

      add_composer :signup_session,
        desc: "Signup session token claims, TTL, and signup rate limit ceilings",
        allowed: Configuration::SignupSession::Config,
        default: Configuration::SignupSession::Config.new

      add_composer :password_recovery_session,
        desc: "Password recovery session token claims, TTL, and recovery rate limit ceilings",
        allowed: Configuration::PasswordRecoverySession::Config,
        default: Configuration::PasswordRecoverySession::Config.new

      # To be Deleted
      add_composer :otp,
        desc: "One Time Password generation is used for ease in quickly validating a users actions. This is good for short term validation requirements as opposed to UserSecrets",
        allowed: Configuration::Otp::Config,
        default: Configuration::Otp::Config.new
    end
  end
end
