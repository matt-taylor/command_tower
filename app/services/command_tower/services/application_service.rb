# frozen_string_literal: true

module CommandTower
  module Services
    class ApplicationService < CommandTower::ServiceBase
      include CommandTower::Transactional

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

      private

      def acceptable_success_result?(result)
        return true if result.nil?
        return result.success? if result.is_a?(ServiceResult)

        true
      end

      def acceptable_failure_result?(result)
        return true if result.is_a?(ServiceResult) && result.failure?
        return true if result.is_a?(CommandTower::Errors::ApplicationError)

        false
      end

      def fail_transaction_type_error_message
        "fail_transaction! requires a failed ServiceResult or ApplicationError"
      end

      def invalid_success_result_message(result)
        "transaction block returned a non-success ServiceResult; " \
          "use fail_transaction!(result) for expected failures (got #{result.class})"
      end

      def handle_transaction_failure(result)
        context.fail!(application_error: application_error_from_transaction_result(result))
      end

      def application_error_from_transaction_result(result)
        return result if result.is_a?(CommandTower::Errors::ApplicationError)

        result.errors.first || CommandTower::Errors::InternalError.new
      end
    end
  end
end
