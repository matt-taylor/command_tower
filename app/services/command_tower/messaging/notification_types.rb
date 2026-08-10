# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
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
