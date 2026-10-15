# frozen_string_literal: true

module CommandTower
  module Messaging
    # Authoritative Messaging retry business rules.
    # Consumed by Execution::Recovery (implementation) and Contract mappers (visibility).
    class DeliveryRetryPolicy
      MAX_ATTEMPTS = 5
      GRACE_WINDOW = 1.minute

      PUSH_RETRY_LIMIT = 2
      SUBMISSION_NOT_SUBMITTED = "not_submitted"
      SUBMISSION_UNCERTAIN = "submission_uncertain"

      class << self
        def retries_exhausted?(delivery)
          delivery.status == ChannelDelivery::STATUS_FAILED_RETRYABLE &&
            delivery.execution_attempt_count >= MAX_ATTEMPTS
        end

        def retry_expected?(delivery)
          delivery.status == ChannelDelivery::STATUS_FAILED_RETRYABLE &&
            !retries_exhausted?(delivery)
        end

        def retry_eligible_at(delivery)
          return nil unless retry_expected?(delivery)

          delivery.updated_at + GRACE_WINDOW
        end

        def push_channel?(delivery)
          delivery.channel_key == "push"
        end

        def max_execution_attempts_for(delivery)
          push_channel?(delivery) ? PUSH_RETRY_LIMIT : MAX_ATTEMPTS
        end

        def confirmed_not_submitted?(attempt)
          attempt.provider_metadata.is_a?(Hash) &&
            attempt.provider_metadata["submission"] == SUBMISSION_NOT_SUBMITTED
        end

        def accepted_ticket_in_attempt?(attempt)
          return true if attempt.status == Messaging::DeliveryAttempt::STATUS_SUCCEEDED

          metadata = attempt.provider_metadata
          return false unless metadata.is_a?(Hash)

          endpoints = metadata.dig("expo", "endpoints")
          return false unless endpoints.is_a?(Array)

          endpoints.any? { |entry| entry["ticket_status"] == "ok" }
        end

        def push_has_open_started_attempt?(delivery)
          delivery.delivery_attempts
            .where(status: Messaging::DeliveryAttempt::STATUS_STARTED, finished_at: nil)
            .exists?
        end

        def latest_finished_attempt(delivery)
          delivery.delivery_attempts
            .where.not(finished_at: nil)
            .order(id: :desc)
            .first
        end

        # Persisted proof only — not tied to channel delivery status.
        def push_has_not_submitted_evidence?(delivery)
          attempt = latest_finished_attempt(delivery)
          attempt.present? && confirmed_not_submitted?(attempt)
        end

        def push_retry_budget_remaining?(delivery)
          delivery.execution_attempt_count < PUSH_RETRY_LIMIT
        end

        # recover_failed! — delivery is failed_retryable.
        def push_redrive_eligible_from_failed_retryable?(delivery)
          return false unless push_channel?(delivery)
          return false unless delivery.status == ChannelDelivery::STATUS_FAILED_RETRYABLE
          return false if push_has_open_started_attempt?(delivery)
          return false unless push_has_not_submitted_evidence?(delivery)

          push_retry_budget_remaining?(delivery)
        end

        # recover_queued! / recover_stale_executing! — delivery may already be queued.
        def push_redrive_eligible_while_queued?(delivery)
          return true unless push_channel?(delivery)
          return false if push_has_open_started_attempt?(delivery)
          return true if delivery.delivery_attempts.none?

          push_has_not_submitted_evidence?(delivery) && push_retry_budget_remaining?(delivery)
        end

        # DeliverWorkflow — may this execution call Expo?
        def push_may_submit_to_provider?(delivery, current_attempt_id:)
          return true unless push_channel?(delivery)

          prior_attempts = delivery.delivery_attempts.where.not(id: current_attempt_id)
          return false if prior_attempts
            .where(status: Messaging::DeliveryAttempt::STATUS_STARTED, finished_at: nil)
            .exists?

          finished = prior_attempts.where.not(finished_at: nil)
          return true if finished.none?

          return false if finished.any? { |attempt| accepted_ticket_in_attempt?(attempt) }

          return false if finished.any? do |attempt|
            attempt.error_code == SUBMISSION_UNCERTAIN ||
              (
                attempt.status == Messaging::DeliveryAttempt::STATUS_FAILED_TERMINAL &&
                  !confirmed_not_submitted?(attempt)
              )
          end

          latest = finished.order(:id).last
          confirmed_not_submitted?(latest) && delivery.execution_attempt_count <= PUSH_RETRY_LIMIT
        end
      end
    end
  end
end
