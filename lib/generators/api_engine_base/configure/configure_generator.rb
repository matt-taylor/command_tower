class ApiEngineBase::ConfigureGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def create_config_file
    create_file Rails.root.join("config", "initializers", "api_engine_base.rb"),
      ApiEngineBase.config.class.composer_generate_config(wrapping: "ApiEngineBase.configure", require_file: "api_engine_base")
  end

  def create_route
    route "mount ApiEngineBase::Engine => \"/\""
  end
end
