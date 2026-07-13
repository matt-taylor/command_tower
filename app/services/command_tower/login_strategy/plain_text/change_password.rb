# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText
  class ChangePassword < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :user, is_a: User, required: true
    validate :current_password, is_a: String, required: true, sensitive: true
    validate :password, is_a: String, required: true, sensitive: true
    validate :password_confirmation, is_a: String, required: true, sensitive: true

    def call
      unless user.authenticate(current_password)
        inline_argument_failure!(errors: { current_password: "Incorrect current password" })
        return
      end

      unless password == password_confirmation
        inline_argument_failure!(errors: { password_confirmation: "Password and confirmation do not match" })
        return
      end

      password_config = CommandTower.config.login.plain_text
      if password.length < password_config.password_length_min || password.length > password_config.password_length_max
        inline_argument_failure!(
          errors: {
            password: "Password length must be between #{password_config.password_length_min} and #{password_config.password_length_max} characters",
          }
        )
        return
      end

      persistence_errors = nil
      infrastructure_failure = false

      ActiveRecord::Base.transaction do
        user.password = password
        user.password_confirmation = password_confirmation

        unless user.save
          persistence_errors = user.errors
          raise ActiveRecord::Rollback
        end

        begin
          user.reset_verifier_token!
        rescue StandardError => e
          log_error("Failed to rotate session verifier for user [#{user.id}]: #{e.class}")
          infrastructure_failure = true
          raise ActiveRecord::Rollback
        end
      end

      if persistence_errors
        log_error("Failed to update password for user [#{user.id}]")
        inline_argument_failure!(errors: persistence_errors)
        return
      end

      if infrastructure_failure
        context.fail!(msg: "Failed to rotate session verifier", status: 500)
        return
      end

      # Detect silent rollback (neither branch set) — should not occur in normal paths
      user.reload
      unless user.authenticate(password)
        log_error("Password change transaction did not persist for user [#{user.id}]")
        context.fail!(msg: "Failed to change password", status: 500)
        return
      end

      log_info("Password changed successfully for user [#{user.id}]")
      context.message = "Password has been successfully changed"
      context.user_id = user.id
    end
  end
end
