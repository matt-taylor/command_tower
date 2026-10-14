# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      # Push urgency levels a declaration may permit (D-8). IOS maps them to the OS.
      URGENCY_LEVELS = %w[normal time_sensitive critical].freeze

      module_function

      def register(declaration)
        Registry.instance.register(declaration)
      end

      def seal
        Registry.instance.seal
      end

      def lookup(key)
        Registry.instance.lookup(key)
      end

      def registered?(key)
        Registry.instance.registered?(key)
      end

      def enumerate
        Registry.instance.enumerate
      end

      def catalog
        Registry.instance.catalog
      end

      def reset!
        Registry.reset!
      end
    end
  end
end
