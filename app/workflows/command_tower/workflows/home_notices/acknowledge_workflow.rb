# frozen_string_literal: true

module CommandTower
  module Workflows
    module HomeNotices
      # `POST /me/home-notices/:id/acknowledge`: rate limit, refuse impersonation, resolve, re-check
      # eligibility, acknowledge.
      #
      # Authorization sequence: the controller authorizes the `me_home_notices` entity before this
      # runs. While impersonating (or when that is unknown) the answer is 403 and nothing is written.
      # The notice is found for `user` only, so a foreign row is a 404, as is a notice that is killed
      # or outside its window. `show?` is never run: a user who saw a notice can always clear it. An
      # unreadable kill switch or a database failure is 503 `home_notices_unavailable`. The shared
      # mutation rate limit fails open when Redis is unavailable.
      #
      # `Services::HomeNotices::Acknowledge` owns the transaction (conditional update plus audit).
      # `after_commit` runs once that transaction has committed; it is the seam for best-effort work
      # that must not roll the acknowledgement back.
      class AcknowledgeWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(user:, notice_id:, impersonating:, app_version: nil, platform: nil)
          limited = CommandTower::Services::HomeNotices::CheckRateLimit.call(user:, bucket: :mutation)
          return failure(errors: limited.errors, http_status: :too_many_requests) if limited.failure?
          return forbidden unless impersonating == false

          request_context = build_context(impersonating:, app_version:, platform:)
          resolved = CommandTower::Services::HomeNotices::ResolveNotice.call(user:, notice_id:, request_context:)
          return rejected(resolved, user:) if resolved.failure?

          eligible = check_eligibility(resolved:, request_context:)
          return rejected(eligible, user:) if eligible.failure?

          acknowledge(user:, resolved:, request_context:)
        end

        private

        def check_eligibility(resolved:, request_context:)
          CommandTower::Services::HomeNotices::CheckMutationEligibility.call(
            notice_class: resolved.data[:notice_class], row: resolved.data[:row], request_context:
          )
        end

        def build_context(impersonating:, app_version:, platform:)
          CommandTower::HomeNotices::Context.new(
            now: Time.current, time_zone: CommandTower::Current.client_time_zone, app_version:, platform:,
            ui_catalog: CommandTower::Current.ui_catalog,
            client_compatibility: CommandTower::Current.client_compatibility_recommendation, impersonating:
          )
        end

        def acknowledge(user:, resolved:, request_context:)
          acknowledged = CommandTower::Services::HomeNotices::Acknowledge.call(
            user:, request_context:, **resolved.data.slice(:notice_class, :row, :period_key)
          )
          return rejected(acknowledged, user:) if acknowledged.failure?

          after_commit(user:, notice_class: resolved.data[:notice_class], data: acknowledged.data)
          respond(acknowledged.data[:recorded])
        rescue ActiveRecord::ActiveRecordError => e
          log_server_error(user:, error: e)
          unavailable
        end

        # Runs after the acknowledge transaction committed, for the first acknowledgement and for an
        # idempotent repeat alike. Logs ids only; further best-effort work hangs here.
        def after_commit(user:, notice_class:, data:)
          CommandTower::Events.publish(
            category: :home_notices, name: "acknowledged",
            payload: { user_id: user.id, notice_key: notice_class.key, notice_id: data[:public_id],
                       recorded: data[:recorded] }
          )
        end

        # Ids and the error class only: the message can carry SQL.
        def log_server_error(user:, error:)
          CommandTower::Events.publish(
            category: :home_notices, name: "ack_server_error",
            payload: { user_id: user.id, error_class: error.class.name }
          )
        end

        def respond(recorded)
          success(
            payload: CommandTower::Serializers::HomeNotices::MutationSerializer.serialize(recorded:),
            http_status: :ok
          )
        end

        # A not-found result stays 404; any other failure (controls unreadable) is 503.
        def rejected(result, user:)
          return forbidden if result.errors.first.is_a?(CommandTower::Errors::ForbiddenError)

          unless result.errors.first.is_a?(CommandTower::Errors::NotFoundError)
            log_server_error(user:, error: result.errors.first)
            return unavailable
          end

          failure(errors: result.errors, http_status: :not_found)
        end

        def forbidden
          failure(errors: [CommandTower::Errors::ForbiddenError.new], http_status: :forbidden)
        end

        def unavailable
          failure(
            errors: [CommandTower::Errors::HomeNotices::UnavailableError.new], http_status: :service_unavailable
          )
        end
      end
    end
  end
end
