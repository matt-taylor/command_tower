# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module PhoneVerification
        # Issues a one-time phone verification code and delivers it over SMS.
        class Send < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            send_unavailable! unless configuration.enable

            phone = user.phone_number.to_s.strip
            phone_missing! if phone.blank?
            already_verified! if user.phone_number_validated

            enforce_resend_cooldown!

            issued = issue_code(phone)
            deliver(phone, issued.secret)

            context.code_length = configuration.verify_code_length
            context.expires_at = issued.record.death_time
            context.phone_number = phone
            context.resend_available_at = Time.current + configuration.resend_cooldown
          end

          private

          def configuration
            CommandTower.config.identity.phone_verification
          end

          def enforce_resend_cooldown!
            cooldown = configuration.resend_cooldown
            return if cooldown.nil? || cooldown <= 0.seconds

            latest = UserSecret
              .where(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION)
              .order(created_at: :desc)
              .first
            return if latest.nil?

            available_at = latest.created_at + cooldown
            return if Time.current >= available_at

            context.fail!(
              application_error: CommandTower::Errors::Account::PhoneVerificationThrottledError.new(
                resend_available_at: available_at
              )
            )
          end

          def issue_code(phone)
            result = CommandTower::Secrets::Generate.(
              user:,
              secret_length: configuration.verify_code_length,
              reason: CommandTower::Secrets::PHONE_VERIFICATION,
              type: CommandTower::Secrets::NUMERIC,
              use_count_max: 1,
              death_time: configuration.verify_code_valid_for,
              extra: phone,
              cleanse: true
            )

            if result.failure?
              log_error("Unable to issue a phone verification code for user [#{user.id}]")
              context.fail!(application_error: CommandTower::Errors::InternalError.new)
            end

            result
          end

          def deliver(phone, secret)
            delivery = CommandTower::Identity::PhoneVerification::SmsTransport.deliver(
              to: phone,
              body: "Your verification code is #{secret}"
            )
            return if delivery.success?

            log_error(
              {
                event: "phone_verification_sms_failed",
                error_code: delivery.error_code,
                to_masked: mask_phone(phone)
              }.to_json
            )
            context.fail!(application_error: CommandTower::Errors::Account::PhoneVerificationSendFailedError.new)
          end

          def send_unavailable!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneVerificationSendFailedError.new)
          end

          def phone_missing!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneMissingError.new)
          end

          def already_verified!
            context.fail!(application_error: CommandTower::Errors::Account::PhoneAlreadyVerifiedError.new)
          end

          def mask_phone(value)
            digits = value.to_s.gsub(/\D/, "")
            return "[redacted]" if digits.length < 4

            "#{"*" * (digits.length - 4)}#{digits[-4,]}"
          end
        end
      end
    end
  end
end
