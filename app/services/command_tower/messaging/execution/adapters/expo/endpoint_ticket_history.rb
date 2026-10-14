# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Expo
          # Read-only lookup over the provider_metadata that earlier attempts of one delivery
          # recorded: which endpoints already hold an accepted Expo ticket and which hit a
          # terminal ticket error. Used so a retry only sends to endpoints still unsettled.
          class EndpointTicketHistory
            History = Data.define(:accepted_ticket_ids, :terminal_error_codes) do
              def settled_endpoint_ids
                accepted_ticket_ids.keys | terminal_error_codes.keys
              end

              def accepted?
                accepted_ticket_ids.any?
              end

              def first_accepted_ticket_id
                accepted_ticket_ids.values.first
              end

              def first_terminal_error_code
                terminal_error_codes.values.first
              end
            end

            def self.call(channel_delivery_id:, excluding_attempt_id:)
              new(channel_delivery_id:, excluding_attempt_id:).call
            end

            def initialize(channel_delivery_id:, excluding_attempt_id:)
              @channel_delivery_id = channel_delivery_id
              @excluding_attempt_id = excluding_attempt_id
            end

            def call
              accepted = {}
              rejected = {}

              recorded_endpoints.each do |entry|
                endpoint_id = entry["endpoint_id"]
                next if endpoint_id.nil?

                case entry["ticket_status"]
                when "ok"
                  if entry["receipt_status"] == "error"
                    # Accepted ticket but the receipt reported a failure: terminal for that device.
                    rejected[endpoint_id] ||= entry["error_code"]
                  else
                    accepted[endpoint_id] ||= entry["ticket_id"]
                  end
                when "error"
                  rejected[endpoint_id] ||= entry["error_code"]
                end
              end

              History.new(
                accepted_ticket_ids: accepted.freeze,
                terminal_error_codes: rejected.except(*accepted.keys).freeze,
              ).freeze
            end

            private

            def recorded_endpoints
              Messaging::DeliveryAttempt
                .where(channel_delivery_id: @channel_delivery_id)
                .where.not(id: @excluding_attempt_id)
                .order(:started_at, :id)
                .pluck(:provider_metadata)
                .flat_map { |metadata| endpoints_in(metadata) }
            end

            def endpoints_in(metadata)
              endpoints = metadata.is_a?(Hash) ? metadata.dig("expo", "endpoints") : nil
              endpoints.is_a?(Array) ? endpoints.grep(Hash) : []
            end
          end
        end
      end
    end
  end
end
