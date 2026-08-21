# frozen_string_literal: true

module CommandTower
  # Generic ActiveRecord atomic boundary shared by ApplicationWorkflow and ApplicationService.
  # Layer-specific result contracts are supplied by includers.
  module Transactional
    class TransactionFailure < StandardError
      attr_reader :result

      def initialize(result)
        @result = result
        super("transaction failed")
      end
    end

    class InvalidTransactionResult < StandardError; end

    def transaction
      result = nil
      ActiveRecord::Base.transaction do
        result = yield
        validate_transaction_success!(result)
      end
      result
    rescue TransactionFailure => e
      handle_transaction_failure(e.result)
    end

    def fail_transaction!(result)
      unless acceptable_failure_result?(result)
        raise InvalidTransactionResult, fail_transaction_type_error_message
      end

      raise TransactionFailure.new(result)
    end

    private

    def validate_transaction_success!(result)
      return if acceptable_success_result?(result)

      raise InvalidTransactionResult, invalid_success_result_message(result)
    end

    def acceptable_success_result?(_result)
      raise NotImplementedError, "#{self.class} must implement #acceptable_success_result?"
    end

    def acceptable_failure_result?(_result)
      raise NotImplementedError, "#{self.class} must implement #acceptable_failure_result?"
    end

    def fail_transaction_type_error_message
      "fail_transaction! requires a failed result"
    end

    def invalid_success_result_message(result)
      "transaction block returned a non-success result; got #{result.class}"
    end

    def handle_transaction_failure(result)
      result
    end
  end
end
