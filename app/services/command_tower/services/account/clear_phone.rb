# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      # Clears the user's phone number. Idempotent when already blank.
      class ClearPhone < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true

        def call
          if user.phone_number.to_s.strip.blank?
            context.user = user
            return
          end

          user.phone_number = nil
          user.phone_number_validated = false
          user.save!

          context.user = user
        end
      end
    end
  end
end
