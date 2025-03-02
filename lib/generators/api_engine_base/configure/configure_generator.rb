class CommandTower::ConfigureGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def create_config_file
    create_file Rails.root.join("config", "initializers", "command_tower.rb"),
      CommandTower.config.class.composer_generate_config(wrapping: "CommandTower.configure", require_file: "command_tower")
  end

  def create_route
    route "mount CommandTower::Engine => \"/\""
  end
end
