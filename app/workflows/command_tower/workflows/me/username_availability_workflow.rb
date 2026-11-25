# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      # Username availability for an authenticated user who may set or change their username
      # (GET /me/username/availability). Limited per user and per IP per day.
      class UsernameAvailabilityWorkflow < CommandTower::Workflows::ApplicationWorkflow
        USER_LIMIT_PER_DAY = 100
        IP_LIMIT_PER_DAY = 300
        WINDOW_SECONDS = 86_400

        retry_strategy :none

        def call(current_user:, username:, client_ip:)
          unless CommandTower::Services::Me::UsernameChangeEligibility.eligible?(current_user)
            return failure(
              errors: [CommandTower::Errors::Account::UsernameChangeNotAllowedError.new],
              http_status: :forbidden
            )
          end

          limited = rate_limit_failure(current_user, client_ip)
          return limited if limited

          check_availability(username)
        end

        private

        def check_availability(username)
          result = CommandTower::Services::Auth::UsernameAvailability.call(username: username)
          return failure(errors: result.errors, http_status: :internal_server_error) unless result.success?

          success(payload: payload(username, result.data), http_status: :ok)
        end

        def payload(username, data)
          email_shaped = username.include?("@")
          valid = data[:valid] && !email_shaped
          CommandTower::Serializers::Auth::UsernameAvailabilitySerializer.serialize(
            valid: valid,
            available: valid && data[:available],
            message: valid ? data[:message] : invalid_message(email_shaped)
          )
        end

        def invalid_message(email_shaped)
          return "Username must not be an email address" if email_shaped

          CommandTower.config.username.username_failure_message
        end

        def rate_limit_failure(user, client_ip)
          day = Time.now.to_i / WINDOW_SECONDS
          [
            ["me:username_availability:user:#{user.id}:#{day}", USER_LIMIT_PER_DAY],
            ["me:username_availability:ip:#{client_ip}:#{day}", IP_LIMIT_PER_DAY]
          ].each do |key, limit|
            error = breach(key, limit)
            return failure(errors: [error], http_status: :too_many_requests) if error
          end
          nil
        end

        # Fails open on a Redis failure; availability is advisory and the unique index guards the write.
        def breach(key, limit)
          result = CommandTower::Services::RateLimits::Check.call(key: key, ttl_seconds: WINDOW_SECONDS)
          return if result.failure? || result.data[:count] <= limit

          ttl = result.data[:ttl]
          CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: ttl.positive? ? ttl : nil)
        end
      end
    end
  end
end
