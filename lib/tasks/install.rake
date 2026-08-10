# frozen_string_literal: true

require "command_tower/install/doctor"

namespace :command_tower do
  desc "Install CommandTower into the host (migrations + optional configure). Does not run db:migrate."
  task install: :environment do
    puts
    puts "=== CommandTower install ==="
    puts

    puts "→ Installing engine migrations (Rails-native)…"
    Rake::Task["command_tower:install:migrations"].reenable
    Rake::Task["command_tower:install:migrations"].invoke
    puts

    skip_configure = %w[1 true yes].include?(ENV["SKIP_CONFIGURE"].to_s.downcase)
    if skip_configure
      puts "→ Skipping configure generator (SKIP_CONFIGURE=#{ENV['SKIP_CONFIGURE']})"
    else
      puts "→ Generating initializer / routes (command_tower:configure)…"
      require "rails/generators"
      generator_args = []
      generator_args << "--skip-routes" if %w[1 true yes].include?(ENV["SKIP_MOUNT"].to_s.downcase)
      generator_args << "--force" if %w[1 true yes].include?(ENV["FORCE"].to_s.downcase)
      Rails::Generators.invoke("command_tower:configure", generator_args)
    end

    puts
    puts "=== Next steps ==="
    puts "  1. Review config/initializers/command_tower.rb (required secrets, optional features)."
    puts "  2. bin/rails db:migrate"
    puts "  3. bin/rails command_tower:doctor"
    puts "  4. Optionally: bin/rails command_tower:users:create"
    puts
    puts "Docs: see the CommandTower gem docs/initializing.md (packaged with the gem)."
    puts "Upgrades: bump the gem, then bin/rails command_tower:install:migrations && bin/rails db:migrate"
    puts "           (or: SKIP_CONFIGURE=1 bin/rails command_tower:install)."
    puts
  end

  desc "Validate CommandTower host setup (secrets, migrations, Rails version)"
  task doctor: :environment do
    require "command_tower/install/doctor"

    puts
    puts "=== CommandTower doctor ==="
    puts

    findings = CommandTower::Install::Doctor.new.run
    failures = 0
    warnings = 0

    findings.each do |finding|
      icon =
        case finding.severity
        when :pass then "[pass]"
        when :warn then "[warn]"
        when :fail then "[fail]"
        else "[????]"
        end

      failures += 1 if finding.severity == :fail
      warnings += 1 if finding.severity == :warn

      puts "#{icon} #{finding.message}"
      puts "       → #{finding.remediation}" if finding.remediation
    end

    puts
    if failures.positive?
      puts "Doctor found #{failures} failure(s) and #{warnings} warning(s)."
      abort("CommandTower doctor failed")
    elsif warnings.positive?
      puts "Doctor passed with #{warnings} warning(s)."
    else
      puts "Doctor passed."
    end
    puts
  end
end
