# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Observability
        class Publisher
          FORBIDDEN_KEYS = %i[title body text metadata email password token].freeze

          class << self
            def info(payload = nil, **kwargs)
              emit(:info, payload || kwargs)
            end

            def warn(payload = nil, **kwargs)
              emit(:warn, payload || kwargs)
            end

            def error(payload = nil, **kwargs)
              emit(:error, payload || kwargs)
            end

            def emit(level, payload)
              hash = payload.respond_to?(:to_h) ? payload.to_h : {}
              event = hash[:event] || hash["event"]
              raise ArgumentError, "messaging event name required" if event.blank?

              name = event.to_s.sub(/\Amessaging\./, "")
              extra = {}
              hash.each do |key, value|
                next if key.to_s == "event"

                extra[key.to_sym] = value
              end
              FORBIDDEN_KEYS.each { |key| extra.delete(key) }
              extra[:log_level] = level
              CommandTower::Events.publish(category: :messaging, name:, payload: extra)
            end
          end
        end
      end
    end
  end
end
