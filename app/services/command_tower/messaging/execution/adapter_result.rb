# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      AdapterResult = Data.define(
        :outcome,
        :normalized_provider_status,
        :provider_message_id,
        :error_code,
      ) do
        OUTCOMES = %i[success retryable_failure terminal_failure].freeze

        def self.build(
          outcome:,
          normalized_provider_status: nil,
          provider_message_id: nil,
          error_code: nil
        )
          raise InvalidAdapterContractError, "arbitrary hashes are not accepted as outcome" if outcome.is_a?(Hash)
          raise InvalidAdapterContractError, "raw exception objects are not accepted" if exception_like?(outcome) ||
            exception_like?(normalized_provider_status) ||
            exception_like?(provider_message_id) ||
            exception_like?(error_code)
          raise InvalidAdapterContractError, "raw exception messages are not accepted" if looks_like_exception_message?(error_code)

          normalized_outcome = normalize_outcome!(outcome)
          validate_optional_string!(normalized_provider_status, "normalized_provider_status")
          validate_optional_string!(provider_message_id, "provider_message_id")
          validate_optional_string!(error_code, "error_code")

          new(
            outcome: normalized_outcome,
            normalized_provider_status:,
            provider_message_id:,
            error_code:,
          ).freeze
        end

        def self.normalize_outcome!(outcome)
          value = outcome.is_a?(String) ? outcome.to_sym : outcome
          unless OUTCOMES.include?(value)
            raise InvalidAdapterContractError, "unsupported outcome: #{outcome.inspect}"
          end

          value
        end
        private_class_method :normalize_outcome!

        def self.validate_optional_string!(value, field_name)
          return if value.nil?
          raise InvalidAdapterContractError, "#{field_name} must be a String" unless value.is_a?(String)
        end
        private_class_method :validate_optional_string!

        def self.exception_like?(value)
          value.is_a?(Exception)
        end
        private_class_method :exception_like?

        def self.looks_like_exception_message?(value)
          # Reject multi-line or stack-trace-like payloads masquerading as error_code.
          value.is_a?(String) && (value.include?("\n") || value.match?(/\.rb:\d+:in/))
        end
        private_class_method :looks_like_exception_message?

        def success?
          outcome == :success
        end

        def retryable_failure?
          outcome == :retryable_failure
        end

        def terminal_failure?
          outcome == :terminal_failure
        end
      end
    end
  end
end
