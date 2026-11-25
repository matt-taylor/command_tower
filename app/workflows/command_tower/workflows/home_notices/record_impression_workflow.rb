# frozen_string_literal: true

module CommandTower
  module Workflows
    module HomeNotices
      # `POST /me/home-notices/:id/impression`: rate limit, resolve, re-check eligibility, record.
      #
      # Authorization sequence: the controller authorizes the `me_home_notices` entity before this
      # runs. The notice is found for `user` only, so a foreign row is a 404, as is a notice that is
      # killed, outside its window, acknowledged or dismissed. While impersonating (or when that is
      # unknown) nothing is written and the answer is `recorded: false`. An unreadable kill switch or
      # a database failure is 503 `home_notices_unavailable`. The shared mutation rate limit fails
      # open when Redis is unavailable.
      #
      # Logs `command_tower.home_notices.impression` with ids only.
      class RecordImpressionWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(user:, notice_id:, impersonating:, app_version: nil, platform: nil)
          limited = CommandTower::Services::HomeNotices::CheckRateLimit.call(user:, bucket: :mutation)
          return failure(errors: limited.errors, http_status: :too_many_requests) if limited.failure?

          request_context = build_context(impersonating:, app_version:, platform:)
          resolved = CommandTower::Services::HomeNotices::ResolveNotice.call(user:, notice_id:, request_context:)
          return rejected(resolved) if resolved.failure?

          eligible = check_eligibility(resolved:, request_context:)
          return rejected(eligible) if eligible.failure?

          record(user:, resolved:, request_context:)
        end

        private

        def check_eligibility(resolved:, request_context:)
          CommandTower::Services::HomeNotices::CheckMutationEligibility.call(
            notice_class: resolved.data[:notice_class], row: resolved.data[:row], request_context:,
            for_impression: true
          )
        end

        def build_context(impersonating:, app_version:, platform:)
          CommandTower::HomeNotices::Context.new(
            now: Time.current, time_zone: CommandTower::Current.client_time_zone, app_version:, platform:,
            ui_catalog: CommandTower::Current.ui_catalog,
            client_compatibility: CommandTower::Current.client_compatibility_recommendation, impersonating:
          )
        end

        def record(user:, resolved:, request_context:)
          recorded = CommandTower::Services::HomeNotices::RecordImpression.call(
            user:, request_context:, **resolved.data.slice(:notice_class, :row, :period_key)
          )
          return rejected(recorded) if recorded.failure?

          log_impression(user:, notice_class: resolved.data[:notice_class], data: recorded.data)
          respond(recorded.data[:recorded])
        rescue ActiveRecord::ActiveRecordError
          unavailable
        end

        def respond(recorded)
          success(
            payload: CommandTower::Serializers::HomeNotices::MutationSerializer.serialize(recorded:),
            http_status: :ok
          )
        end

        # A not-found result stays 404; any other failure (controls unreadable) is 503.
        def rejected(result)
          return unavailable unless result.errors.first.is_a?(CommandTower::Errors::NotFoundError)

          failure(errors: result.errors, http_status: :not_found)
        end

        def unavailable
          failure(
            errors: [CommandTower::Errors::HomeNotices::UnavailableError.new], http_status: :service_unavailable
          )
        end

        def log_impression(user:, notice_class:, data:)
          CommandTower::Events.publish(
            category: :home_notices, name: "impression",
            payload: { user_id: user.id, notice_key: notice_class.key, notice_id: data[:public_id],
                       recorded: data[:recorded], first_impression: data[:first_impression] }
          )
        end
      end
    end
  end
end
