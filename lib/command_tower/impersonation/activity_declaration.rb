# frozen_string_literal: true

module CommandTower
  module Impersonation
    module ActivityDeclaration
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def impersonation_activity!
          @impersonation_activity = true
        end

        def impersonation_activity?
          return @impersonation_activity unless @impersonation_activity.nil?

          superclass.respond_to?(:impersonation_activity?) ? superclass.impersonation_activity? : false
        end
      end
    end
  end
end
