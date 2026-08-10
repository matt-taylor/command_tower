# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      class ChangePassword < CommandTower::Services::ApplicationService
        FIELD_KEYS = {
          current_password: :currentPassword,
          password: :password,
          password_confirmation: :passwordConfirmation
        }.freeze

        SUCCESS_MESSAGE = "Password has been successfully changed"

        validate :user, is_a: User, required: true
        validate :current_password, is_a: String, required: true, sensitive: true
        validate :password, is_a: String, required: true, sensitive: true
        validate :password_confirmation, is_a: String, required: true, sensitive: true

        def call
          reject!(current_password: "Incorrect current password") unless user.authenticate(current_password)
          reject!(password_confirmation: "Password and confirmation do not match") unless password == password_confirmation

          config = CommandTower.config.login.plain_text
          if password.length < config.password_length_min || password.length > config.password_length_max
            reject!(
              password: "Password length must be between #{config.password_length_min} and #{config.password_length_max} characters"
            )
          end

          persistence_errors = nil
          infrastructure_failure = false

          ActiveRecord::Base.transaction do
            user.password = password
            user.password_confirmation = password_confirmation

            unless user.save
              persistence_errors = user.errors.to_hash.transform_values { Array(_1).join(", ") }
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
            reject!(persistence_errors)
          end

          if infrastructure_failure
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end

          # Detect silent rollback (neither branch set) — should not occur in normal paths
          user.reload
          unless user.authenticate(password)
            log_error("Password change transaction did not persist for user [#{user.id}]")
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end

          log_info("Password changed successfully for user [#{user.id}]")
          context.message = SUCCESS_MESSAGE
        end

        private

        def reject!(errors)
          details = errors.each_with_object({}) do |(key, message), mapped|
            mapped[FIELD_KEYS.fetch(key.to_sym, key)] = message
          end

          context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
        end
      end
    end
  end
end
