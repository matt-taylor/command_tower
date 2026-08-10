# frozen_string_literal: true

require "net/smtp"
require "socket"
require "timeout"

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Email
          class Adapter
            RETRYABLE_ERRORS = [
              Timeout::Error,
              Net::OpenTimeout,
              Net::ReadTimeout,
              Errno::ECONNREFUSED,
              Errno::ECONNRESET,
              Errno::EHOSTUNREACH,
              Errno::ENETUNREACH,
              SocketError,
            ].freeze

            TERMINAL_SMTP_ERRORS = [
              Net::SMTPAuthenticationError,
              Net::SMTPFatalError,
              Net::SMTPSyntaxError,
            ].freeze

            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

              begin
                message = Messaging::ChannelMailer.deliver_rendered(rendered: request.rendered).deliver
                AdapterResult.build(
                  outcome: :success,
                  normalized_provider_status: "accepted",
                  provider_message_id: extract_message_id(message),
                )
              rescue ArgumentError
                AdapterResult.build(
                  outcome: :terminal_failure,
                  error_code: "invalid_recipient",
                )
              rescue *TERMINAL_SMTP_ERRORS
                AdapterResult.build(
                  outcome: :terminal_failure,
                  error_code: "smtp_rejected",
                )
              rescue *RETRYABLE_ERRORS
                AdapterResult.build(
                  outcome: :retryable_failure,
                  error_code: "smtp_transient",
                )
              rescue StandardError
                AdapterResult.build(
                  outcome: :retryable_failure,
                  error_code: "smtp_transient",
                )
              end
            end

            private

            def extract_message_id(message)
              return nil unless message.respond_to?(:message_id)

              id = message.message_id
              return nil if id.nil? || id.to_s.strip.empty?

              id.to_s
            end
          end
        end
      end
    end
  end
end
