# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Communications
        # Reusable multi-recipient fan-out: host supplies stable user ids; CT reloads
        # User and calls single-user Produce per recipient. No audience queries here.
        class ProduceMany < CommandTower::Services::ApplicationService
          SYNC_MAX = 25
          FAILURE_DETAIL_CAP = 25
          EXECUTION_MODES = %i[async sync].freeze

          validate :user_ids, is_a: Array, required: true
          validate :notification_type_key, is_a: String, required: true
          validate :campaign_identity, is_a: String, required: true
          validate :title, is_a: String, required: true
          validate :body, is_a: String, required: true
          validate :platform_enabled_channels, is_a: Array, required: true
          validate :metadata, is_a: Hash, required: false
          validate :execution_mode, is_one: EXECUTION_MODES, required: false, default: :async

          def call
            ids = normalize_user_ids
            mode = normalized_execution_mode

            if mode == :sync && ids.size > SYNC_MAX
              context.fail!(
                application_error: CommandTower::Errors::ValidationError.new(
                  details: {
                    execution_mode: "sync mode allows at most #{SYNC_MAX} recipients (got #{ids.size})",
                  }
                )
              )
              return
            end

            if mode == :async
              schedule_async(ids)
            else
              produce_sync(ids)
            end
          end

          private

          def normalize_user_ids
            Array(user_ids).map { |id| Integer(id) }
          rescue ArgumentError, TypeError
            context.fail!(
              application_error: CommandTower::Errors::ValidationError.new(
                details: { user_ids: "must be an array of integer user ids" }
              )
            )
            []
          end

          def normalized_execution_mode
            mode = execution_mode
            mode = mode.to_sym if mode.is_a?(String)
            mode = :async if mode.nil?
            mode
          end

          def schedule_async(ids)
            enqueued = 0
            enqueue_failed = 0

            ids.each do |user_id|
              CommandTower::Messaging::Communications::ProduceRecipientJob.perform_later(
                user_id,
                recipient_job_attrs
              )
              enqueued += 1
            rescue StandardError
              enqueue_failed += 1
            end

            context.requested = ids.size
            context.enqueued = enqueued
            context.enqueue_failed = enqueue_failed
            context.campaign_identity = campaign_identity
            context.mode = :async
          end

          def produce_sync(ids)
            accepted = 0
            failed = 0
            skipped = 0
            failures = []

            ids.each do |user_id|
              user = User.find_by(id: user_id)
              unless user
                skipped += 1
                push_failure(failures, user_id, "user_not_found")
                next
              end

              result = produce_for(user)
              if result.success?
                accepted += 1
              else
                failed += 1
                error = result.errors.first
                push_failure(failures, user_id, error.respond_to?(:code) ? error.code : error.class.name)
              end
            rescue StandardError => error
              failed += 1
              push_failure(failures, user_id, error.class.name)
            end

            context.requested = ids.size
            context.accepted = accepted
            context.failed = failed
            context.skipped = skipped
            context.failures = failures
            context.mode = :sync
            context.campaign_identity = campaign_identity
          end

          def produce_for(user)
            CommandTower::Services::Messaging::Communications::Produce.call(
              user:,
              notification_type_key:,
              host_event_identity: "#{campaign_identity}/#{user.id}",
              title:,
              body:,
              metadata:,
              platform_enabled_channels:,
            )
          end

          def recipient_job_attrs
            {
              "notification_type_key" => notification_type_key,
              "campaign_identity" => campaign_identity,
              "title" => title,
              "body" => body,
              "platform_enabled_channels" => platform_enabled_channels,
              "metadata" => metadata,
            }
          end

          def push_failure(failures, user_id, error_code)
            return if failures.size >= FAILURE_DETAIL_CAP

            failures << { user_id:, error_code: }
          end
        end
      end
    end
  end
end
