# frozen_string_literal: true

module CommandTower
  module Workflows
    module HomeNotices
      # `POST /me/home-notices/:id/dismiss`: rate limit, refuse impersonation, resolve, re-check
      # eligibility, dismiss.
      #
      # Authorization sequence: the controller authorizes the `me_home_notices` entity before this
      # runs. While impersonating (or when that is unknown) the answer is 403 and nothing is written.
      # The notice is found for `user` only, so a foreign row is a 404, as is a notice that is killed
      # or outside its window. A blocking notice is 422 and nothing is written. `show?` is never run.
      # An unreadable kill switch or a database failure is 503 `home_notices_unavailable`. The shared
      # mutation rate limit fails open when Redis is unavailable.
      #
      # `Services::HomeNotices::Dismiss` owns the transaction (conditional update plus audit).
      class DismissWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(user:, notice_id:, impersonating:, app_version: nil, platform: nil)
          limited = CommandTower::Services::HomeNotices::CheckRateLimit.call(user:, bucket: :mutation)
          return failure(errors: limited.errors, http_status: :too_many_requests) if limited.failure?
          return forbidden unless impersonating == false

          request_context = build_context(impersonating:, app_version:, platform:)
          resolved = CommandTower::Services::HomeNotices::ResolveNotice.call(user:, notice_id:, request_context:)
          return rejected(resolved) if resolved.failure?

          eligible = check_eligibility(resolved:, request_context:)
          return rejected(eligible) if eligible.failure?

          dismiss(user:, resolved:, request_context:)
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

        def dismiss(user:, resolved:, request_context:)
          dismissed = CommandTower::Services::HomeNotices::Dismiss.call(
            user:, request_context:, **resolved.data.slice(:notice_class, :row, :period_key)
          )
          return rejected(dismissed) if dismissed.failure?

          log_dismissed(user:, notice_class: resolved.data[:notice_class], data: dismissed.data)
          respond(notice_class: resolved.data[:notice_class], data: dismissed.data)
        rescue ActiveRecord::ActiveRecordError
          unavailable
        end

        def log_dismissed(user:, notice_class:, data:)
          CommandTower::Events.publish(
            category: :home_notices, name: "dismissed",
            payload: { user_id: user.id, notice_key: notice_class.key, notice_id: data[:public_id],
                       recorded: data[:recorded] }
          )
        end

        def respond(notice_class:, data:)
          success(
            payload: CommandTower::Serializers::HomeNotices::DismissalSerializer.serialize(
              notice_class:, public_id: data[:public_id], dismissed_until: data[:dismissed_until]
            ),
            http_status: :ok
          )
        end

        # Not found stays 404 and a blocking dismiss is 422; any other failure (controls unreadable)
        # is 503.
        def rejected(result)
          error = result.errors.first
          return forbidden if error.is_a?(CommandTower::Errors::ForbiddenError)
          return invalid(result) if error.is_a?(CommandTower::Errors::ValidationError)
          return unavailable unless error.is_a?(CommandTower::Errors::NotFoundError)

          failure(errors: result.errors, http_status: :not_found)
        end

        def invalid(result)
          failure(errors: result.errors, http_status: :unprocessable_entity)
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
