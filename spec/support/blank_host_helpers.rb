# frozen_string_literal: true

module BlankHostHelpers
  module_function

  def engine_root
    CommandTower::Engine.root
  end

  def blank_root
    engine_root.join("tmp", "blank_host_install")
  end

  def mysql_database
    ENV.fetch("BLANK_HOST_MYSQL_DATABASE", "command_tower_blank_host_test")
  end

  def host_env
    {
      "PATH" => ENV.fetch("PATH"),
      "HOME" => ENV.fetch("HOME", "/root"),
      "TERM" => ENV["TERM"],
      "LANG" => ENV["LANG"],
      "BUNDLE_GEMFILE" => blank_root.join("Gemfile").to_s,
      "BUNDLE_PATH" => blank_root.join("vendor/bundle").to_s,
      "BUNDLE_APP_CONFIG" => blank_root.join("vendor/bundle").to_s,
      "GEM_HOME" => ENV["GEM_HOME"],
      "GEM_PATH" => ENV["GEM_PATH"],
      "RAILS_ENV" => "development",
      "MYSQL_HOST" => ENV.fetch("MYSQL_HOST", "mysql"),
      "MYSQL_PORT" => ENV.fetch("MYSQL_PORT", "3306"),
      "MYSQL_USER" => ENV.fetch("MYSQL_USER", "root"),
      "MYSQL_PASSWORD" => ENV.fetch("MYSQL_PASSWORD", "root"),
      "REDIS_URL" => ENV.fetch("REDIS_URL", "redis://redis"),
      "SECRET_KEY_BASE" => "blank-host-secret-key-base-for-phase-53",
      "SIGNUP_SESSION_JWT_SECRET" => "blank-host-signup-secret",
      "PASSWORD_RECOVERY_SESSION_JWT_SECRET" => "blank-host-password-recovery-secret",
    }.compact
  end

  def sh!(*args, env: host_env)
    require "open3"
    stdout, stderr, status = Open3.capture3(env, *args, chdir: blank_root.to_s, unsetenv_others: true)
    unless status.success?
      raise "Command failed (#{status.exitstatus}): #{args.join(' ')}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    end

    stdout
  end

  def write_database_yml!
    File.write(blank_root.join("config/database.yml"), <<~YAML)
      default: &default
        adapter: mysql2
        encoding: utf8mb4
        pool: 5
        host: <%= ENV.fetch("MYSQL_HOST", "mysql") %>
        port: <%= ENV.fetch("MYSQL_PORT", 3306) %>
        username: <%= ENV.fetch("MYSQL_USER", "root") %>
        password: <%= ENV.fetch("MYSQL_PASSWORD", "root") %>

      development:
        <<: *default
        database: #{mysql_database}

      test:
        <<: *default
        database: #{mysql_database}_test
    YAML
  end

  def drop_blank_database!
    require "mysql2"
    client = Mysql2::Client.new(
      host: ENV.fetch("MYSQL_HOST", "mysql"),
      port: ENV.fetch("MYSQL_PORT", "3306").to_i,
      username: ENV.fetch("MYSQL_USER", "root"),
      password: ENV.fetch("MYSQL_PASSWORD", "root"),
    )
    client.query("DROP DATABASE IF EXISTS `#{mysql_database}`")
    client.query("DROP DATABASE IF EXISTS `#{mysql_database}_test`")
    client.close
  rescue Mysql2::Error => e
    warn "blank host DB cleanup warning: #{e.message}"
  end
end

RSpec.configure do |config|
  config.include BlankHostHelpers, :blank_host
end
