# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Observability
        class StructuredLogger
          COMPONENT = "command_tower.messaging"
          FORBIDDEN_KEYS = %w[
            title
            body
            text
            metadata
            email
            password
            token
          ].freeze

          class << self
            def info(payload)
              emit(:info, payload)
            end

            def warn(payload)
              emit(:warn, payload)
            end

            def error(payload)
              emit(:error, payload)
            end

            private

            def emit(level, payload)
              envelope = build_envelope(level, payload)
              Rails.logger.public_send(level, envelope.to_json)
            rescue StandardError
              nil
            end

            def build_envelope(level, payload)
              compact = payload.to_h.transform_keys(&:to_s).except(*FORBIDDEN_KEYS)
              compact.reject! { |_key, value| value.nil? }

              {
                "timestamp" => Time.now.utc.iso8601(3),
                "level" => level.to_s,
                "component" => COMPONENT,
              }.merge(compact)
            end
          end
        end
      end
    end
  end
end
