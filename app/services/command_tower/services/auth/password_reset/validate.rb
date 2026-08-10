# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordReset
        # Reports whether a reset token is still usable without consuming it.
        class Validate < CommandTower::Services::ApplicationService
          include TokenVerification

          validate :token, is_a: String, required: true, sensitive: true
          validate :email, is_a: String, required: false, sensitive: true

          def call
            require_email!

            redemption = redeem_token!(access_count: false)
            match_email!(token_user: redemption.user)

            log_info("Password reset token validated for user [#{redemption.user.id}]")

            context.valid = true
            context.expires_at = token_expires_at&.to_s
          end
        end
      end
    end
  end
end
