# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Pushover
          # Execution adapter: decrypts credentials for the readiness-resolved
          # endpoint and sends via Messaging::Pushover::Transport.
          class Adapter
            CREDENTIAL_REJECTION_CODES = %i[
              invalid_user
              invalid_token
              invalid_credentials
            ].freeze

            def initialize(configuration: nil, transport: nil, secret_reader: nil)
              @configuration = configuration || Configuration.new
              @transport = transport || Messaging::Pushover::Transport
              @secret_reader = secret_reader || Endpoints::SecretReader
            end

            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

              rendered = request.rendered
              unless rendered.is_a?(Rendering::RenderedPushoverPayload)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "render_failed")
              end

              unless @configuration.pushover_configured?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              end

              endpoint_id = Integer(rendered.recipient_address, exception: false)
              if endpoint_id.nil? || endpoint_id <= 0
                return AdapterResult.build(outcome: :terminal_failure, error_code: "invalid_recipient")
              end

              delivery = Messaging::ChannelDelivery.includes(:communication).find_by(id: request.channel_delivery_id)
              owner_user_id = delivery&.communication&.user_id
              if owner_user_id.nil?
                return AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
              end

              credentials = read_credentials(owner_user_id:, endpoint_id:)
              return credentials if credentials.is_a?(AdapterResult)

              result = @transport.send_message!(
                user_key: credentials.fetch(:user_key),
                application_token: credentials.fetch(:application_token),
                title: rendered.title,
                message: rendered.message,
              )
              map_result(result, owner_user_id:, endpoint_id:)
            rescue StandardError
              AdapterResult.build(outcome: :retryable_failure, error_code: "pushover_transient")
            end

            private

            def read_credentials(owner_user_id:, endpoint_id:)
              @secret_reader.read_pushover_credentials!(owner_user_id:, endpoint_id:)
            rescue Endpoints::NotFoundError, Endpoints::ValidationError
              AdapterResult.build(outcome: :terminal_failure, error_code: "recipient_missing")
            end

            def map_result(result, owner_user_id:, endpoint_id:)
              unless result.is_a?(Messaging::Pushover::Result)
                return AdapterResult.build(outcome: :retryable_failure, error_code: "pushover_transient")
              end

              if result.success?
                return AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: "accepted",
                  provider_message_id: result.provider_request_id,
                )
              end

              code = result.error_code.to_sym
              if CREDENTIAL_REJECTION_CODES.include?(code)
                mark_invalid_best_effort!(owner_user_id:, endpoint_id:)
                return AdapterResult.build(outcome: :terminal_failure, error_code: "pushover_rejected")
              end

              case code
              when :adapter_disabled
                AdapterResult.build(outcome: :terminal_failure, error_code: "adapter_unconfigured")
              when :timeout, :provider_unavailable, :rate_limited
                AdapterResult.build(outcome: :retryable_failure, error_code: "pushover_transient")
              else
                AdapterResult.build(outcome: :retryable_failure, error_code: "pushover_transient")
              end
            end

            def mark_invalid_best_effort!(owner_user_id:, endpoint_id:)
              Endpoints.mark_invalid(owner_user_id:, endpoint_id:)
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end
