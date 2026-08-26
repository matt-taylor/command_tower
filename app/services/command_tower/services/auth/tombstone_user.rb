# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class TombstoneUser < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true

        def call
          if user.deleted?
            context.user = user
            context.changed = false
            return
          end

          user_id = user.id
          scrub_password = SecureRandom.hex(32)
          user.assign_attributes(
            deleted_at: Time.current,
            first_name: "",
            last_name: "",
            email: User.tombstone_email_for(user_id),
            username: User.tombstone_username_for(user_id),
            phone_number: nil,
            phone_number_validated: false,
            email_validated: false,
            roles: []
          )
          user.password = scrub_password
          user.password_confirmation = scrub_password

          unless user.save(validate: false)
            context.fail!(
              application_error: CommandTower::Errors::InternalError.new
            )
            return
          end

          user.reset_verifier_token!

          context.user = user.reload
          context.changed = true
        end
      end
    end
  end
end
