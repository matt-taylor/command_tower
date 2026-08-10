# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class UsernameAvailability < CommandTower::Services::ApplicationService
        validate :username, is_a: String, required: true

        def call
          availability = CommandTower::Username::Available.call(username:, force_query: true)

          context.valid = availability.valid?
          context.available = availability.available?
          context.message = availability_message(valid: availability.valid?, available: availability.available?)
        end

        private

        def availability_message(valid:, available:)
          return CommandTower.config.username.username_failure_message unless valid
          return "Username is available" if available

          "Username is already taken"
        end
      end
    end
  end
end
