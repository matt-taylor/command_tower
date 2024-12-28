  require_relative "lib/api_engine_base/version"

Gem::Specification.new do |spec|
  spec.name        = "api_engine_base"
  spec.version     = ApiEngineBase::VERSION
  spec.authors     = [ "" ]
  spec.email       = [ "" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of ApiEngineBase."
  spec.description = "TODO: Description of ApiEngineBase."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

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
