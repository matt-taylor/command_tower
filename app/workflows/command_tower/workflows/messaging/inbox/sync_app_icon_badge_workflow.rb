# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Inbox
        # Job-entry orchestration: send a silent `{to, badge}` push so the app icon badge matches the
        # recipient's unread count.
        #
        # Coalescing: BadgeSyncScheduler takes the pending marker (`SET NX EX`) at enqueue time and
        # enqueues the job with a short wait, so a burst of changes yields one job. This job clears the
        # marker first and only then reads the count, so it sees every change made before the clear. A
        # change committed after the clear takes a new marker and sends again (trailing edge). Redis
        # failures fail open: the badge is sent without coalescing.
        #
        # Best effort: send failures are logged by class only (never tokens, bodies or payloads) and
        # never raised. Nothing is sent when the flag is off, while impersonating, or unless the Expo
        # adapter is `http`.
        class SyncAppIconBadgeWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          PUSH_CHANNEL_KEY = "push"

          def call(user_id:)
            reason = skip_reason
            return noop(reason) if reason

            deliver(user_id)
          rescue StandardError => e
            log_failure(user_id:, error: e)
            success(payload: { outcome: :failed }, http_status: :ok)
          end

          private

          def skip_reason
            return :disabled unless CommandTower.config.messaging.inbox.badge_sync_push == true
            return :impersonating if CommandTower::Messaging::Inbox::ImpersonationAudit.impersonating?

            :adapter_not_http unless expo_configuration.adapter_name == "http"
          end

          # Marker is cleared before the count is read so a later change is never lost.
          def deliver(user_id)
            clear_pending_marker(user_id)
            tokens = push_tokens(user_id)
            return noop(:no_devices) if tokens.empty?

            badge = CommandTower::Messaging::Inbox.unread_count(recipient_id: user_id).badge_count
            send_badge(tokens:, badge:)
            success(payload: { outcome: :sent, devices: tokens.size, badge: }, http_status: :ok)
          end

          def noop(reason)
            success(payload: { outcome: :noop, reason: }, http_status: :ok)
          end

          def expo_configuration
            CommandTower::Messaging::Execution::Adapters::Expo::Configuration.new
          end

          def marker_key(user_id)
            CommandTower::Messaging::Inbox::BadgeSyncScheduler.marker_key(user_id)
          end

          def clear_pending_marker(user_id)
            CommandTower::RedisConnection.with { |redis| redis.del(marker_key(user_id)) }
          rescue Redis::BaseError, Timeout::Error
            nil
          end

          def push_tokens(user_id)
            views = CommandTower::Messaging::Endpoints.list(owner_user_id: user_id, channel_key: PUSH_CHANNEL_KEY)
            views.filter_map do |view|
              next unless view.lifecycle_state == "active" && view.verification_state == "verified"

              CommandTower::Messaging::Endpoints::SecretReader.read!(owner_user_id: user_id, endpoint_id: view.id)
            rescue CommandTower::Messaging::Endpoints::Error
              nil
            end
          end

          def send_badge(tokens:, badge:)
            client = CommandTower::Messaging::Execution::Adapters::Expo::HttpClient.new(
              configuration: expo_configuration
            )
            client.send_messages(tokens.map { |token| { "to" => token, "badge" => badge } })
          end

          def log_failure(user_id:, error:)
            Rails.logger.warn(
              "[CommandTower::Messaging] badge sync failed user_id=#{user_id} reason=#{error.class.name}"
            )
          end
        end
      end
    end
  end
end
