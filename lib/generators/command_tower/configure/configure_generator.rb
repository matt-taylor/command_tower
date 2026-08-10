# frozen_string_literal: true

class CommandTower::ConfigureGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  class_option :skip_routes,
    type: :boolean,
    default: false,
    desc: "Do not mount CommandTower::Engine in config/routes.rb"

  class_option :force,
    type: :boolean,
    default: false,
    desc: "Overwrite an existing config/initializers/command_tower.rb"

  def create_config_file
    relative = "config/initializers/command_tower.rb"
    path = File.join(destination_root, relative)
    if File.exist?(path) && !options[:force]
      say_status :skip, "#{relative} (already present; pass --force to overwrite)", :yellow
      return
    end

    create_file relative,
      CommandTower.config.class.composer_generate_config(wrapping: "CommandTower.configure", require_file: "command_tower")
  end

  def create_route
    return if options[:skip_routes]

    routes_path = File.join(destination_root, "config/routes.rb")
    if File.exist?(routes_path) && File.read(routes_path).include?("CommandTower::Engine")
      say_status :skip, "config/routes.rb (CommandTower::Engine already mounted)", :yellow
      return
    end

    route 'mount CommandTower::Engine => "/"'
  end
end
