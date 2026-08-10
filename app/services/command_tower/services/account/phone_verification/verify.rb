# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module PhoneVerification
        # Redeems a phone verification code and marks the phone validated.
        class Verify < CommandTower::Services::ApplicationService
          EXPIRED_FRAGMENT = "Expired"

          validate :user, is_a: User, required: true
          validate :code, is_a: String, required: true, sensitive: true

          def call
            phone_missing! if user.phone_number.to_s.strip.blank?

            if user.phone_number_validated
              context.user = user
              context.already_verified = true
              return
            end

            User.transaction do
              locked = User.lock.find(user.id)
              phone = locked.phone_number.to_s.strip

              phone_missing! if phone.blank?

              if locked.phone_number_validated
                context.user = locked
                context.already_verified = true
                return
              end

              redeem!(locked, phone)

              locked.update!(phone_number_validated: true)
              CommandTower::Secrets::Cleanse.(user: locked, reason: CommandTower::Secrets::PHONE_VERIFICATION)
              context.user = locked.reload
              context.already_verified = false
            end
          end

          private

          def redeem!(locked, phone)
            challenge = UserSecret.find_by(
              secret: code,
              reason: CommandTower::Secrets::PHONE_VERIFICATION
            )

            invalid_code! if challenge.nil? || challenge.user_id != locked.id
            stale_challenge! if challenge.extra.to_s != phone

            result = CommandTower::Secrets::Verify.(
              secret: code,
              reason: CommandTower::Secrets::PHONE_VERIFICATION,
              access_count: true
            )

            if result.failure?
              expired_code! if result.msg.to_s.include?(EXPIRED_FRAGMENT)
              invalid_code!
            end

            invalid_code! if result.user != locked
          end

          def phone_missing!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneMissingError.new)
          end

          def invalid_code!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneVerificationCodeInvalidError.new)
          end

          def stale_challenge!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneVerificationStaleError.new)
          end

          def expired_code!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneVerificationExpiredError.new)
          end
        end
      end
    end
  end
end
