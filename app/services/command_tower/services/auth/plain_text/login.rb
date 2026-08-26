# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PlainText
        class Login < CommandTower::Services::ApplicationService
          validate :identifier, is_a: String, required: true, sensitive: true
          validate :password, is_a: String, required: true, sensitive: true

          def call
            user = User.not_deleted.where(username: identifier).or(User.not_deleted.where(email: identifier)).first
            if user.nil?
              audit_login_failed(affected_user: nil, outcome: "unknown_identifier")
              invalid_credentials!
            end

            if user.authenticate(password)
              user.successful_login += 1
              user.password_consecutive_fail = 0
              user.save
            else
              user.password_consecutive_fail += 1
              user.save
              log_warn("Valid identifier. Incorrect password. Consecutive Password failures: #{user.password_consecutive_fail}")
              audit_login_failed(affected_user: user, outcome: "invalid_password")
              invalid_credentials!
            end

            context.user = user
            context.token = CommandTower::Jwt::LoginCreate.(user:).token
            context.expires_at = token_expires_at_from_ttl
          end

          private

          def invalid_credentials!
            context.fail!(application_error: CommandTower::Errors::Auth::InvalidCredentialsError.new)
          end

          def audit_login_failed(affected_user:, outcome:)
            audit(:login_failed, affected_user:, changes: {}, metadata: { outcome: })
          end

          def token_expires_at_from_ttl
            CommandTower.config.jwt.ttl.from_now.to_time.to_s
          end
        end
      end
    end
  end
end
