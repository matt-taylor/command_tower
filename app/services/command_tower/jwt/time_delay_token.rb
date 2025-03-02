# frozen_string_literal: true

module CommandTower::Jwt
  class TimeDelayToken < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :expires_in, is_a: ActiveSupport::Duration, required: true

    def call
      context.token = Encode.(payload:).token
    end

    def payload
      { expires_in: expires_in }
    end
  end
end
