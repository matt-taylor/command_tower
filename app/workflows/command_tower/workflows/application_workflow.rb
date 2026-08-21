# frozen_string_literal: true

module CommandTower
  module Workflows
    class ApplicationWorkflow
      include CommandTower::Transactional
      include CommandTower::Execution::ContextAccess
      include CommandTower::Logging::LifecycleDeclaration
      include CommandTower::Impersonation::ActivityDeclaration
      log_lifecycle!

      TransactionFailure = CommandTower::Transactional::TransactionFailure
      InvalidTransactionResult = CommandTower::Transactional::InvalidTransactionResult

      ALLOWED_RETRY_STRATEGIES = %i[none delayed_continuation scheduled_cadence].freeze

      protected :transaction, :fail_transaction!

      # Programmer error: deferred result used with a strategy that forbids continuation.
      class InvalidDeferredResult < StandardError; end

      # Programmer error: delayed continuation requires a job instance to replay.
      class DelayedContinuationRequiresJob < StandardError; end

      class << self
        def call(**args)
          validate_retry_strategy!
          CommandTower::Events.around_execution(layer: :workflow, subject: name, log_lifecycle: lifecycle_loggable?) do |record|
            begin
              record[:result] = new.call(**args)
            rescue TransactionFailure => e
              record[:result] = e.result
            rescue InvalidTransactionResult
              raise
            rescue StandardError => e
              record[:unexpected] = e
              record[:result] = WorkflowResult.failure(
                errors: [CommandTower::Errors::InternalError.new(cause: e)],
                http_status: :internal_server_error
              )
            end
            mark_impersonation_activity!(record[:result])
          end
        end

        # Job transport entry. Unexpected exceptions re-raise. Deferred continuation
        # is scheduled by CommandTower when the strategy is :delayed_continuation.
        def call_from_job(job: nil, continuation_attempt: 1, **args)
          validate_retry_strategy!
          result = invoke_for_job(**args)
          handle_job_result(
            result,
            job: job,
            continuation_attempt: Integer(continuation_attempt),
            **args
          )
        end

        def retry_strategy(strategy, max_attempts: nil)
          @retry_strategy = strategy&.to_sym
          @continuation_max_attempts = max_attempts
        end

        def declared_retry_strategy
          @retry_strategy
        end

        def continuation_max_attempts
          @continuation_max_attempts
        end

        def mark_impersonation_activity!(result)
          return unless impersonation_activity?
          return unless result.is_a?(CommandTower::Workflows::WorkflowResult) && result.success?

          CommandTower::Current.impersonation_activity_recorded = true
        end
        private :mark_impersonation_activity!

        def validate_retry_strategy!
          raise "#{name} must declare retry_strategy (:none, :delayed_continuation, or :scheduled_cadence)" if @retry_strategy.nil?

          if @retry_strategy == :sidekiq
            raise "#{name} retry_strategy :sidekiq is not supported; use :delayed_continuation"
          end

          unless ALLOWED_RETRY_STRATEGIES.include?(@retry_strategy)
            raise "#{name} retry_strategy #{@retry_strategy.inspect} is invalid " \
                  "(allowed: :none, :delayed_continuation, :scheduled_cadence)"
          end

          if @retry_strategy == :delayed_continuation
            max = @continuation_max_attempts
            unless max.is_a?(Integer) && max >= 1
              raise "#{name} retry_strategy :delayed_continuation requires max_attempts: >= 1"
            end
          elsif !@continuation_max_attempts.nil?
            raise "#{name} retry_strategy #{@retry_strategy.inspect} cannot declare max_attempts"
          end
        end

        private

        def invoke_for_job(**args)
          CommandTower::Events.around_execution(layer: :workflow, subject: name, log_lifecycle: lifecycle_loggable?) do |record|
            begin
              record[:result] = new.call(**args)
            rescue TransactionFailure => e
              record[:result] = e.result
            rescue StandardError => e
              record[:unexpected] = e
              raise
            end
          end
        end

        def handle_job_result(result, job:, continuation_attempt:, **args)
          if result.deferred?
            return handle_deferred(result, job: job, continuation_attempt: continuation_attempt, **args)
          end

          if result.failure? && result.meta[:propagate_to_job]
            error = Array(result.errors).first
            raise error if error

            raise StandardError, "#{name} failed for job without errors"
          end

          result
        end

        def handle_deferred(result, job:, continuation_attempt:, **args)
          unless @retry_strategy == :delayed_continuation
            raise InvalidDeferredResult,
                  "#{name} returned deferred but retry_strategy is #{@retry_strategy.inspect}"
          end

          max_attempts = Integer(@continuation_max_attempts)
          if continuation_attempt >= max_attempts
            raise CommandTower::Errors::ContinuationExhaustedError.new(
              details: { attempt: continuation_attempt, max_attempts: max_attempts }
            )
          end

          if job.nil?
            raise DelayedContinuationRequiresJob,
                  "#{name} deferred continuation requires call_from_job(job:)"
          end

          wait = [Integer(result.retry_after), 1].max
          job.class.set(wait: wait.seconds).perform_later(
            **args.merge(continuation_attempt: continuation_attempt + 1)
          )
          result
        end
      end

      def call(**)
        raise NotImplementedError
      end

      protected

      def success(payload:, http_status: :ok, response_effects: nil, meta: {})
        WorkflowResult.success(payload:, http_status:, response_effects:, meta:)
      end

      def failure(errors:, http_status:, response_effects: nil, meta: {})
        WorkflowResult.failure(errors:, http_status:, response_effects:, meta:)
      end

      def deferred(reason:, retry_after:, payload: {}, http_status: :accepted, response_effects: nil, meta: {})
        WorkflowResult.deferred(
          reason:,
          retry_after:,
          payload:,
          http_status:,
          response_effects:,
          meta:
        )
      end

      private

      def acceptable_success_result?(result)
        result.is_a?(WorkflowResult) && result.success?
      end

      def acceptable_failure_result?(result)
        result.is_a?(WorkflowResult) && result.failure?
      end

      def fail_transaction_type_error_message
        "fail_transaction! requires a failed WorkflowResult"
      end

      def invalid_success_result_message(result)
        unless result.is_a?(WorkflowResult)
          return "transaction block must return a WorkflowResult; got #{result.class}"
        end

        "transaction block returned a non-success WorkflowResult; " \
          "use fail_transaction!(failure(...)) for expected failures"
      end
    end
  end
end
