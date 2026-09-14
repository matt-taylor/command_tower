source "https://rubygems.org"

# Specify your gem's dependencies in command_tower.gemspec.
gemspec

gem "puma"

gem "sprockets-rails"


# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# gem "json_schematize", path: "/local/json_schematize"

gem "rails", ENV.fetch("BUNDLER_RAILS_VERSION", "~> 8")
gem "rspec-rails"
gem "rspec_junit_formatter"

gem "rack-cors"

gem "database_cleaner-active_record"
gem "factory_bot"
gem "faker"
gem "null-logger", require: "null_logger"
gem "simplecov", require: false
gem "timecop"

gem "mysql2"
gem "webmock"

# json 3.x removed the second positional `options` arg from `JSON.parse` and
# the `quirks_mode:` keyword from `JSON.generate`. ActiveSupport (both the 7.x
# and 8.x lines currently supported by our CI matrix) still calls
# `::JSON.parse(json, options)` positionally in `ActiveSupport::JSON.decode`,
# and ActiveSupport 7.x's `.encode` still passes `quirks_mode:` to
# `JSON.generate`. Both raise `ArgumentError` under json 3.x. Pin below 3 so
# `bundle install` (which re-resolves from scratch per Ruby/Rails matrix cell
# in CI, discarding Gemfile.lock) never floats onto an incompatible json.
gem "json", "< 3"

group :development do
  gem "annotate"
end
