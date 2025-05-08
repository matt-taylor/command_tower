source "https://rubygems.org"

# Specify your gem's dependencies in command_tower.gemspec.
gemspec

gem "puma"

gem "sprockets-rails"

gem "pry"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# gem "json_schematize", path: "/local/json_schematize"

gem "rails", ENV.fetch("BUNDLER_RAILS_VERSION", "~> 7")
gem "rspec-rails"
gem "rspec_junit_formatter"

gem "rack-cors"

gem "database_cleaner-active_record"
gem "factory_bot"
gem "faker"
gem "null-logger", require: "null_logger"
gem "rails-controller-testing"
gem "simplecov", require: false
gem "timecop"

gem "mysql2"

group :development do
  gem "annotate"
end
