# frozen_string_literal: true

module FoundationProof
  class EchoDeserializer < CommandTower::Deserializers::ApplicationDeserializer
    Input = Data.define(:message, :limit)

    DEFAULT_LIMIT = 10
    MAX_LIMIT = 100

    def call(params)
      message_raw = unwrap(fetch_param(params, :message, "message"))
      return message_raw if deserializer_result?(message_raw)

      message = unwrap(require_string(message_raw, code: "missing_required_fields", field: "message"))
      return message if deserializer_result?(message)

      limit_raw = unwrap(fetch_param(params, :limit, "limit"))
      return limit_raw if deserializer_result?(limit_raw)

      limit = if limit_raw.nil? || (limit_raw.is_a?(String) && limit_raw.strip.empty?)
                DEFAULT_LIMIT
              else
                unwrapped = unwrap(
                  require_integer(
                    limit_raw,
                    code: "invalid_limit",
                    field: "limit",
                    min: 1,
                    max: MAX_LIMIT
                  )
                )
                return unwrapped if deserializer_result?(unwrapped)

                unwrapped
              end

      success(Input.new(message: message, limit: limit))
    end
  end
end
