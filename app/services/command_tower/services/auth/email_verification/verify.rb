# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module EmailVerification
        class Verify < CommandTower::Services::ApplicationService
          ALREADY_VERIFIED_MESSAGE = "Email is already verified"
          VERIFIED_MESSAGE = "Successfully verified email"
          INVALID_CODE_MESSAGE = "Incorrect verification code provided"

          validate :user, is_a: User, required: true
          validate :code, is_a: String, required: true

          def call
            if user.email_validated
              context.message = ALREADY_VERIFIED_MESSAGE
              return
            end

            result = CommandTower::Secrets::Verify.(
              secret: code,
              reason: CommandTower::Secrets::EMAIL_VERIFICIATION
            )
            invalid_code! if result.failure?

            if result.user != user
              log_warn("Yikes! The logged in user does not match the correct code. Kick them back out and do not verify")
              invalid_code!
            end

            user.update(email_validated: true)

            context.user = user.reload
            context.message = VERIFIED_MESSAGE
          end

          private

          def invalid_code!
            context.fail!(
              application_error: CommandTower::Errors::Auth::VerificationCodeInvalidError.new(
                details: { code: INVALID_CODE_MESSAGE }
              )
            )
          end
        end
      end
    end
  end
end
