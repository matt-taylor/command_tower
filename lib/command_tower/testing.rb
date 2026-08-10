# frozen_string_literal: true

module CommandTower
  # Explicit host/test entry for shared FactoryBot definitions and related
  # testing bootstrap. Not loaded in production via Railtie.
  module Testing
    class << self
      # Preferred host entry. Currently loads factories; reserved for future
      # shared testing setup (helpers, config checks).
      def install!
        load_factories!
      end

      # Load CommandTower FactoryBot definitions exactly once.
      # Loads files under Engine.root/spec/factories explicitly (does not mutate
      # global definition_file_paths / find_definitions).
      def load_factories!
        return if factories_loaded?

        begin
          require "factory_bot"
        rescue LoadError
          raise LoadError,
                "CommandTower::Testing requires the factory_bot gem. " \
                "Add `factory_bot` or `factory_bot_rails` to your host test group."
        end

        factory_files.each { |path| Kernel.load(path) }
        @factories_loaded = true
        true
      end

      def factories_loaded?
        @factories_loaded == true
      end

      # Reset loader state (specs only). Does not undefine FactoryBot factories.
      def reset_factories_loaded_flag!
        @factories_loaded = false
      end

      # Ensures COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET for endpoint factories
      # in non-production test environments when unset.
      def ensure_endpoint_secret!
        return unless ENV["COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET"].to_s.empty?

        ENV["COMMAND_TOWER_MESSAGING_ENDPOINT_SECRET"] =
          "test-messaging-endpoint-secret-not-for-production"
      end

      def factories_path
        CommandTower::Engine.root.join("spec/factories")
      end

      private

      def factory_files
        Dir[factories_path.join("**/*.rb").to_s].sort
      end
    end
  end
end
