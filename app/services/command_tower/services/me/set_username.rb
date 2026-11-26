# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Sets or changes the caller's own username. Eligibility, rate limit (10 per hour per user),
      # shape rules, case-insensitive uniqueness among non-deleted users, and the `username_set` audit.
      class SetUsername < CommandTower::Services::ApplicationService
        LIMIT_PER_HOUR = 10
        WINDOW_SECONDS = 3600

        validate :user, is_a: User, required: true
        validate :username, is_a: String, required: true

        def call
          normalized = username.to_s.strip
          guard!(normalized)
          change_username!(normalized) unless user.username.to_s == normalized

          context.user = user.reload
        rescue ActiveRecord::RecordNotUnique => e
          fail_with!(CommandTower::Errors::Account::UsernameTakenError.new(cause: e))
        rescue ActiveRecord::RecordInvalid => e
          fail_for_invalid_record!(e)
        end

        private

        def guard!(normalized)
          unless UsernameChangeEligibility.eligible?(user)
            fail_with!(CommandTower::Errors::Account::UsernameChangeNotAllowedError.new)
          end

          enforce_rate_limit!
          reject_invalid_shape!(normalized)
        end

        def fail_with!(error)
          context.fail!(application_error: error)
        end

        # Fails open on a Redis failure; the unique index still guards the write.
        def enforce_rate_limit!
          result = CommandTower::Services::RateLimits::Check.call(
            key: "me:username:user:#{user.id}:#{Time.now.to_i / WINDOW_SECONDS}",
            ttl_seconds: WINDOW_SECONDS
          )
          return if result.failure? || result.data[:count] <= LIMIT_PER_HOUR

          ttl = result.data[:ttl]
          fail_with!(
            CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: ttl.positive? ? ttl : nil)
          )
        end

        def reject_invalid_shape!(normalized)
          fail_with!(validation_error("Username must not be an email address")) if normalized.include?("@")
          return if CommandTower::Username::Available.call(username: normalized).valid?

          fail_with!(validation_error(CommandTower.config.username.username_failure_message))
        end

        def validation_error(message)
          CommandTower::Errors::ValidationError.new(details: { username: message })
        end

        def change_username!(normalized)
          fail_with!(CommandTower::Errors::Account::UsernameTakenError.new) if taken?(normalized)

          changes = { username: { from: user.username, to: normalized } }
          ActiveRecord::Base.transaction do
            apply!(normalized)
            audit(:username_set, subject: user, affected_user: user, changes:)
          end
        end

        def taken?(normalized)
          User.not_deleted.where.not(id: user.id).exists?(["LOWER(username) = ?", normalized.downcase])
        end

        def apply!(normalized)
          outcome = CommandTower::UserAttributes::Mutate.call(user:, username: normalized)
          return if outcome.success?

          details = outcome.invalid_argument_hash.transform_values { |entry| entry[:msg].to_s }
          fail_with!(CommandTower::Errors::ValidationError.new(details:))
        end

        def fail_for_invalid_record!(error)
          record = error.record
          entries = record ? Array(record.errors.details[:username]) : []
          taken = entries.any? { |entry| entry[:error] == :taken }
          fail_with!(CommandTower::Errors::Account::UsernameTakenError.new(cause: error)) if taken

          raise error
        end
      end
    end
  end
end
