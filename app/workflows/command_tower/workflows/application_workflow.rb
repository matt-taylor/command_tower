# frozen_string_literal: true

module CommandTower
  module Workflows
    class ApplicationWorkflow
      class << self
        def call(**args)
          validate_retry_strategy!
          begin
            new.call(**args)
          rescue StandardError => e
            log_unknown_exception(e)
            WorkflowResult.failure(
              errors: [CommandTower::Errors::InternalError.new(cause: e)],
              http_status: :internal_server_error
            )
          end
        end

        # Job transport entry: same WorkflowResult as `.call`, but raises when the
        # workflow marks the failure for ActiveJob propagation (`meta[:propagate_to_job]`).
        # Controllers continue to use `.call` and render envelopes from WorkflowResult.
        def call_from_job(**args)
          result = call(**args)
          if result.failure? && result.meta[:propagate_to_job]
            error = Array(result.errors).first
            raise error if error

            raise StandardError, "#{name} failed for job without errors"
          end

          result
        end

        def retry_strategy(strategy)
          @retry_strategy = strategy
        end

        def validate_retry_strategy!
          return if @retry_strategy

          raise "#{name} must declare retry_strategy (:none, :sidekiq, or :scheduled_cadence)"
        end

        def log_unknown_exception(exception)
          Rails.logger.error(
            "[#{name}] Unknown workflow exception: #{exception.class}: #{exception.message}\n" \
            "#{exception.backtrace&.join("\n")}"
          )
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
    end
  end
end
