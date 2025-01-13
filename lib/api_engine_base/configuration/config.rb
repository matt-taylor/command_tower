# frozen_string_literal: true

require "singleton"
require "class_composer"
require "api_engine_base/configuration/base"
require "api_engine_base/configuration/email/config"
require "api_engine_base/configuration/jwt/config"
require "api_engine_base/configuration/login/config"
require "api_engine_base/configuration/otp/config"
require "api_engine_base/configuration/username/config"
require "api_engine_base/configuration/application/config"
require "api_engine_base/configuration/admin/config"
require "api_engine_base/configuration/authorization/config"
require "api_engine_base/configuration/user/config"

module ApiEngineBase
  module Configuration
    class Config < ::ApiEngineBase::Configuration::Base
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

      add_composer_blocking :admin,
        desc: "Admin configuration for the app",
        composer_class: Configuration::Admin::Config,
        enable_attr: :enable

      # To be Deleted
      add_composer :otp,
        desc: "One Time Password generator is used for all Code validation. This describes defaults not set in other configurations",
        allowed: Configuration::Otp::Config,
        default: Configuration::Otp::Config.new
    end
  end
end

