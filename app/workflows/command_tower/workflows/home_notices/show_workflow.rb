# frozen_string_literal: true

module CommandTower
  module Workflows
    module HomeNotices
      # `GET /me/home-notices`: rate limit, select, serialize.
      #
      # Authorization sequence: the controller authorizes the `me_home_notices` entity before this
      # runs. `impersonating` comes from the authenticated boundary: true or nil (unknown) redacts
      # the documents and sets `readOnly`. A client below UI catalog 2 gets both notices null without
      # selection. When the controls cannot be read, `Select` returns no picks, so the response is
      # also both null.
      class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(user:, impersonating:, app_version: nil, platform: nil)
          limited = CommandTower::Services::HomeNotices::CheckRateLimit.call(user:)
          return failure(errors: limited.errors, http_status: :too_many_requests) if limited.failure?

          picks = select_notices(user:, impersonating:, app_version:, platform:)
          success(
            payload: CommandTower::Serializers::HomeNotices::SelectionSerializer.serialize(
              blocking: picks[:blocking], dismissible: picks[:dismissible], read_only: impersonating != false
            ),
            http_status: :ok
          )
        end

        private

        def select_notices(user:, impersonating:, app_version:, platform:)
          return {} if CommandTower::Current.ui_catalog.to_i < CommandTower::Services::HomeNotices::Compose::MIN_CATALOG

          request_context = CommandTower::HomeNotices::Context.new(
            now: Time.current, time_zone: CommandTower::Current.client_time_zone, app_version:, platform:,
            ui_catalog: CommandTower::Current.ui_catalog,
            client_compatibility: CommandTower::Current.client_compatibility_recommendation, impersonating:
          )
          CommandTower::Services::HomeNotices::Select.call(user:, request_context:).data
        end
      end
    end
  end
end
