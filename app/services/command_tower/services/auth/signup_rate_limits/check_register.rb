# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module SignupRateLimits
        class CheckRegister < CommandTower::Services::ApplicationService
          include Enforcement

          validate :client_ip, is_a: String, required: true

          def call
            enforce!(
              key: "signup:rate:ip:#{normalize_ip(client_ip)}:register:1h:#{hour_bucket}",
              ttl_seconds: 3600,
              limit: limits.ip_register_hour,
              scope: :ip
            )
          end
        end
      end
    end
  end
end
