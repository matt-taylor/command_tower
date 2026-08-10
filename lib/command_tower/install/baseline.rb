# frozen_string_literal: true

module CommandTower
  module Install
    # Compact final-schema baseline authored in CommandTower (Phase 5.2).
    # Hosts receive copies via Rails-native `command_tower:install:migrations`.
    module Baseline
      ENGINE_MIGRATION_BASENAMES = %w[
        20260805000001_create_command_tower_users.rb
        20260805000002_create_command_tower_user_secrets.rb
        20260805000003_create_command_tower_messaging_core.rb
        20260805000004_create_messaging_notification_preferences.rb
        20260805000005_create_messaging_endpoints_and_pushover_credentials.rb
      ].freeze

      module_function

      def migrate_dir
        CommandTower::Engine.root.join("db/migrate")
      end

      def engine_migration_basenames
        Dir.children(migrate_dir).grep(/\.rb\z/).sort
      end

      def host_installed_migrations(host_root = Rails.root)
        Dir.glob(File.join(host_root.to_s, "db/migrate", "*command_tower*.rb")).map { |p| File.basename(p) }.sort
      end
    end
  end
end
