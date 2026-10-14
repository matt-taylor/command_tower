# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # Collects Expo receipts that were still pending when a push attempt finished.
      # Called at the end of the recovery sweep. It only reads receipts and records them in the
      # attempt's provider_metadata; it never sends, enqueues, or changes delivery or attempt status.
      #
      # Poll window: attempts that finished within RECEIPT_WINDOW. A bounded, best-effort cleanup
      # read just behind the window marks entries that are still pending as unchecked (no HTTP).
      class ExpoReceiptCollection
        RECEIPT_WINDOW = 15.minutes
        BATCH_SIZE = 100
        RECEIPT_ID_CHUNK_SIZE = 1000
        DEVICE_INVALID_ERRORS = %w[DeviceNotRegistered].freeze
        COUNT_KEYS = %i[
          attempt_count
          receipt_ok_count
          receipt_error_count
          receipt_unchecked_count
          invalidated_count
          poll_failure_count
          update_failure_count
        ].freeze

        def self.call(configuration: nil, http_client: nil, now: Time.current)
          new(configuration:, http_client:, now:).call
        end

        def initialize(configuration: nil, http_client: nil, now: Time.current)
          @configuration = configuration || Adapters::Expo::Configuration.new
          @http_client = http_client
          @now = now
          @counts = COUNT_KEYS.index_with { 0 }
        end

        def call
          return @counts unless http_adapter?

          cleanup_pass
          poll_pass
          @counts
        rescue StandardError
          @counts[:update_failure_count] += 1
          @counts
        ensure
          OperationLogger.receipts_collected(@counts) if http_adapter?
        end

        private

        def http_adapter?
          @configuration.expo_configured? && @configuration.adapter_name == "http"
        end

        def http_client
          @http_client ||= Adapters::Expo::HttpClient.new(configuration: @configuration)
        end

        def window_start
          @now - RECEIPT_WINDOW
        end

        def poll_scope
          attempts_scope.where(finished_at: window_start..)
        end

        def cleanup_scope
          attempts_scope.where(finished_at: (@now - (2 * RECEIPT_WINDOW))...window_start)
        end

        def attempts_scope
          Messaging::DeliveryAttempt.where.not(provider_metadata: nil)
        end

        # Keyset batches ordered by (finished_at, id) so the finished_at index serves the range.
        def each_batch(scope)
          table = Messaging::DeliveryAttempt.arel_table
          cursor = nil

          loop do
            batch_scope = scope.order(:finished_at, :id).limit(BATCH_SIZE)
            if cursor
              batch_scope = batch_scope.where(
                table[:finished_at].gt(cursor[:finished_at]).or(
                  table[:finished_at].eq(cursor[:finished_at]).and(table[:id].gt(cursor[:id])),
                ),
              )
            end

            rows = batch_scope.preload(channel_delivery: :communication).to_a
            break if rows.empty?

            yield rows
            break if rows.size < BATCH_SIZE

            cursor = { finished_at: rows.last.finished_at, id: rows.last.id }
          end
        end

        def cleanup_pass
          each_batch(cleanup_scope) do |rows|
            rows.each do |attempt|
              next if pending_entries(attempt.provider_metadata).empty?

              update_attempt(attempt, receipts: {}, expire: true)
            end
          end
        end

        def poll_pass
          each_batch(poll_scope) do |rows|
            pending = rows.select { |attempt| pending_entries(attempt.provider_metadata).any? }
            next if pending.empty?

            requested_ids = pending.flat_map { |attempt| pending_entries(attempt.provider_metadata).pluck("ticket_id") }
            receipts = fetch_receipts(requested_ids.uniq)
            next if receipts.empty?

            pending.each do |attempt|
              ticket_ids = pending_entries(attempt.provider_metadata).pluck("ticket_id")
              next unless ticket_ids.any? { |ticket_id| receipts.key?(ticket_id) }

              update_attempt(attempt, receipts:, expire: false)
            end
          end
        end

        def fetch_receipts(ticket_ids)
          receipts = {}
          ticket_ids.each_slice(RECEIPT_ID_CHUNK_SIZE) do |slice|
            result = http_client.get_receipts(slice)
            if result.is_a?(Hash) && result[:ok] && result[:receipts].is_a?(Hash)
              receipts.merge!(result[:receipts])
            else
              @counts[:poll_failure_count] += 1
            end
          rescue StandardError
            @counts[:poll_failure_count] += 1
          end
          receipts
        end

        def pending_entries(metadata)
          endpoints = metadata.is_a?(Hash) ? metadata.dig("expo", "endpoints") : nil
          return [] unless endpoints.is_a?(Array)

          endpoints.select do |entry|
            entry.is_a?(Hash) &&
              entry["ticket_status"] == "ok" &&
              entry["receipt_status"] == "pending" &&
              entry["ticket_id"].present?
          end
        end

        # One short transaction per attempt. A failure rolls back only this attempt and the pass
        # continues with the next one; its entries stay pending for a later sweep.
        def update_attempt(attempt, receipts:, expire:)
          deltas = Hash.new(0)

          ActiveRecord::Base.transaction do
            attempt.lock!
            metadata = attempt.provider_metadata.deep_dup
            changed = false

            pending_entries(metadata).each do |entry|
              outcome = apply_outcome!(attempt:, entry:, receipt: receipts[entry["ticket_id"]], expire:, deltas:)
              changed = true if outcome
            end

            attempt.update!(provider_metadata: metadata) if changed
            deltas[:attempt_count] += 1 if changed
          end

          deltas.each { |key, value| @counts[key] += value }
        rescue StandardError
          @counts[:update_failure_count] += 1
        end

        # Returns :unchecked, :ok, or :error when the entry changed, nil when it stays pending.
        def apply_outcome!(attempt:, entry:, receipt:, expire:, deltas:)
          if expire
            entry["receipt_status"] = "unchecked"
            deltas[:receipt_unchecked_count] += 1
            return :unchecked
          end

          case receipt&.dig(:status)
          when "ok"
            entry["receipt_status"] = "ok"
            deltas[:receipt_ok_count] += 1
            :ok
          when "error"
            record_receipt_error!(attempt:, entry:, receipt:, deltas:)
            :error
          end
        end

        def record_receipt_error!(attempt:, entry:, receipt:, deltas:)
          entry["receipt_status"] = "error"
          if DEVICE_INVALID_ERRORS.include?(receipt[:error].to_s)
            entry["error_code"] = "expo_device_invalid"
            invalidate_endpoint!(attempt:, endpoint_id: entry["endpoint_id"], deltas:)
          else
            entry["error_code"] = "expo_rejected"
          end
          deltas[:receipt_error_count] += 1
        end

        def invalidate_endpoint!(attempt:, endpoint_id:, deltas:)
          owner_user_id = attempt.channel_delivery&.communication&.user_id
          return if owner_user_id.nil? || endpoint_id.nil?

          Endpoints.mark_invalid(owner_user_id:, endpoint_id:)
          deltas[:invalidated_count] += 1
        rescue Endpoints::NotFoundError, Endpoints::ValidationError
          # The device endpoint is already gone; the receipt error is still recorded.
          nil
        end
      end
    end
  end
end
