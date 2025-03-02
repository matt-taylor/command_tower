
require_relative "lib/command_tower/version"

Gem::Specification.new do |spec|
  spec.name        = "command_tower"
  spec.version     = CommandTower::VERSION
  spec.authors     = [ "matt-taylor" ]
  spec.email       = [ "" ]
  spec.homepage    = "https://github.com/matt-taylor/command_tower"
  spec.summary     = "CommandTower is the Base API to handle all the things you don't want to for a Rails API only backend serving a Dedicated frontend"
  spec.description = "CommandTower is the Base API to handle all the things you don't want to for a Rails API only backend serving a Dedicated frontend"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/matt-taylor/command_tower"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rotp"
  spec.add_dependency 'rails', '>= 6.0', '< 9.0'
  spec.add_dependency "jwt", ">= 2"
  spec.add_dependency "bcrypt", ">= 3"
  spec.add_dependency "interactor"
  spec.add_dependency "class_composer", ">= 2"
  spec.add_dependency "json_schematize", ">= 0.11"
end
