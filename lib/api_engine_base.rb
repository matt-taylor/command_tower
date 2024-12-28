require "api_engine_base/version"
require "api_engine_base/engine"
require "api_engine_base/configuration/config"

module ApiEngineBase
  class Error < StandardError; end

  def self.config
    @config ||= Configuration::Config.new
  end

  def self.configure
    yield(config)
  end

  def self.config=(configuration)
    raise ArgumentError, "Expected Configuration::Config. Given #{configuration.class}" unless Configuration::Config === configuration

    @config = configuration
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
