
require_relative "lib/api_engine_base/version"

Gem::Specification.new do |spec|
  spec.name        = "api_engine_base"
  spec.version     = ApiEngineBase::VERSION
  spec.authors     = [ "matt-taylor" ]
  spec.email       = [ "" ]
  spec.homepage    = "https://github.com/matt-taylor/api_engine_base"
  spec.summary     = "ApiEngineBase is the Base API to handle all the things you don't want to for a Rails API only backend serving a Dedicated frontend"
  spec.description = "ApiEngineBase is the Base API to handle all the things you don't want to for a Rails API only backend serving a Dedicated frontend"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = "https://github.com/matt-taylor/api_engine_base"
  spec.metadata["source_code_uri"] = "https://github.com/matt-taylor/api_engine_base"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rotp"
  spec.add_dependency "rails", "~> 7"
  spec.add_dependency "jwt", ">= 2"
  spec.add_dependency "bcrypt", ">= 3"
  spec.add_dependency "interactor"
  spec.add_dependency "class_composer", ">= 2"
  spec.add_dependency "json_schematize", ">= 0.10"
end
