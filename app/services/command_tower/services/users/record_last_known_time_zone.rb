# frozen_string_literal: true

module CommandTower
  module Services
    module Users
      # Stores the zone a client last sent in X-Time-Zone on the user. Writes only when the zone
      # changed and the previous write is more than an hour old. Fails open and never logs
      # (services do not use Rails.logger).
      class RecordLastKnownTimeZone < CommandTower::Services::ApplicationService
        MIN_WRITE_INTERVAL = 1.hour

        validate :user, is_a: User, required: true
        validate :zone, is_a: String, required: true

        def call
          context.written = false
          return unless write_due?

          write
          context.written = true
        rescue StandardError
          context.written = false
        end

        private

        def write_due?
          return false if user.last_known_timezone == zone

          last_write = user.last_known_timezone_update
          last_write.nil? || last_write <= MIN_WRITE_INTERVAL.ago
        end

        def write
          user.update_columns(last_known_timezone: zone, last_known_timezone_update: Time.current) # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end
  end
end
