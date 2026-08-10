# frozen_string_literal: true

module CommandTower
  module Auth
    PasswordRecoverySessionContext = Data.define(:jti, :expires_at, :client_ip) do
      def remaining_seconds
        [expires_at.to_i - Time.now.to_i, 0].max
      end
    end
  end
end
