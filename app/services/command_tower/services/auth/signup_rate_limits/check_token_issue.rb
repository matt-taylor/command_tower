# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module SignupRateLimits
        class CheckTokenIssue < CommandTower::Services::ApplicationService
          include Enforcement

          validate :client_ip, is_a: String, required: true

          def call
            ip_key = normalize_ip(client_ip)

            enforce!(
              key: "signup:rate:ip:#{ip_key}:issue:1m:#{minute_bucket}",
              ttl_seconds: 60,
              limit: limits.ip_issue_burst,
              scope: :ip
            )

            enforce!(
              key: "signup:rate:ip:#{ip_key}:issue:1h:#{hour_bucket}",
              ttl_seconds: 3600,
              limit: limits.ip_issue_hour,
              scope: :ip
            )
          end
        end
      end
    end
  end
end
