# frozen_string_literal: true

module CommandTower
  module Logging
    module LifecycleDeclaration
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def log_lifecycle!
          @lifecycle_loggable = true
        end

        def disable_lifecycle_logging!
          @lifecycle_loggable = false
        end

        def lifecycle_loggable?
          return @lifecycle_loggable unless @lifecycle_loggable.nil?

          superclass.respond_to?(:lifecycle_loggable?) ? superclass.lifecycle_loggable? : false
        end
      end
    end
  end
end
