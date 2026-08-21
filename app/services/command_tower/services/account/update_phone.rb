# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      # Sets or replaces the user's canonical phone number. Never marks it verified.
      class UpdatePhone < CommandTower::Services::ApplicationService
        DUPLICATE_MESSAGE = "has already been taken"

        validate :user, is_a: User, required: true
        validate :phone_number, is_a: String, required: true

          def call
          normalized = normalize

          if user.phone_number == normalized
            context.user = user
            return
          end

          previous = user.phone_number
          user.phone_number = normalized
          user.phone_number_validated = false

          begin
            user.save!
          rescue ActiveRecord::RecordNotUnique
            reject!(DUPLICATE_MESSAGE)
          end

          audit(
            :phone_updated,
            subject: user,
            affected_user: user,
            changes: { phone: { from: previous, to: normalized } }
          )

          context.user = user
        end

        private

        def normalize
          result = CommandTower::Identity::Phone::Normalizer.call(phone_number:)
          reject!(result.message) if result.failure?

          result.normalized
        end

        def reject!(message)
          context.fail!(
            application_error: CommandTower::Errors::ValidationError.new(details: { phoneNumber: message })
          )
        end
      end
    end
  end
end
