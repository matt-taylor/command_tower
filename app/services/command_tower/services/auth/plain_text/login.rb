# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PlainText
        class Login < CommandTower::Services::ApplicationService
          validate :identifier, is_a: String, required: true, sensitive: true
          validate :password, is_a: String, required: true, sensitive: true

          # Digest of a throwaway secret at the cost has_secure_password currently uses
          # (min cost in test). Computed once, on first use after boot.
          def self.dummy_digest
            @dummy_digest ||= begin
              cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
              BCrypt::Password.create(SecureRandom.hex(16), cost:).to_s
            end
          end

          # client_ip is optional so callers without a request (console, tests) skip the IP bucket.
          validate :client_ip, is_a: String

          # Optional device attributes recorded on the device session.
          validate :installation_id, is_a: String
          validate :platform, is_a: String
          validate :app_version, is_a: String

          def call
            enforce_ip_limit!

            user = User.not_deleted.where(username: identifier).or(User.not_deleted.where(email: identifier)).first
            lockout = LoginRateLimits::Lockout.new(subject: LoginRateLimits::Lockout.subject_for(user:, identifier:))
            lock = lockout.status

            # bcrypt always runs (real or dummy digest) so a locked, known and unknown
            # identifier cost the same, and a lock answers even a correct password.
            authenticated = user ? user.authenticate(password) : dummy_password_match?

            if lock.locked?
              audit_login_failed(affected_user: user, outcome: "locked")
              rate_limited!(lock.retry_after)
            end

            if user.nil?
              audit_login_failed(affected_user: nil, outcome: "unknown_identifier")
              fail_login!(lockout)
            elsif authenticated
              user.successful_login += 1
              user.password_consecutive_fail = 0
              user.save
              lockout.clear
            else
              user.password_consecutive_fail += 1
              user.save
              log_warn("Valid identifier. Incorrect password. Consecutive Password failures: #{user.password_consecutive_fail}")
              audit_login_failed(affected_user: user, outcome: "invalid_password")
              fail_login!(lockout)
            end

            context.user = user
            issued = IssueSession.call(user:, installation_id:, platform:, app_version:)
            context.fail!(application_error: issued.errors.first) if issued.failure?

            context.device_session = issued.data[:device_session]
            context.token = issued.data[:token]
            context.expires_at = issued.data[:expires_at]
            context.installation_id = issued.data[:installation_id]
            context.set_installation_cookie = issued.data[:set_installation_cookie]
          end

          private

          def enforce_ip_limit!
            return if client_ip.blank?

            result = LoginRateLimits::CheckIp.call(client_ip:)
            context.fail!(application_error: result.errors.first) if result.failure?
          end

          # Equalize request-side work with the known-user path: one bcrypt comparison.
          def dummy_password_match?
            BCrypt::Password.new(self.class.dummy_digest).is_password?(password)
            false
          end

          # A failed attempt counts; when it trips the lock the caller is told so (429),
          # with the same answer for known and unknown identifiers.
          def fail_login!(lockout)
            lock = lockout.record_failure
            rate_limited!(lock.retry_after) if lock.locked?
            invalid_credentials!
          end

          def rate_limited!(retry_after)
            context.fail!(application_error: CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: retry_after.to_i.positive? ? retry_after.to_i : nil))
          end

          def invalid_credentials!
            context.fail!(application_error: CommandTower::Errors::Auth::InvalidCredentialsError.new)
          end

          def audit_login_failed(affected_user:, outcome:)
            audit(:login_failed, affected_user:, changes: {}, metadata: { outcome: })
          end
        end
      end
    end
  end
end
