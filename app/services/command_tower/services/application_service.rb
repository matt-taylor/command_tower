# frozen_string_literal: true

module CommandTower
  module Services
    class ApplicationService < CommandTower::ServiceBase
      on_argument_validation :fail_early

      def self.inherited(subclass)
        super
        subclass.on_argument_validation(:fail_early)
      end

      class << self
        def call(context = {})
          interactor_context = super
          ServiceResult.from_interactor_context(interactor_context)
        end
      end
    end
  end
end
