# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module PasswordRecoverySession
      class RateLimits < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :jti_send,
          desc: "Max password reset sends allowed for a single recovery session (jti)",
          allowed: Integer,
          default: 5

        add_composer :ip_issue_burst,
          desc: "Max recovery session tokens a single IP may request per minute",
          allowed: Integer,
          default: 5

        add_composer :ip_issue_hour,
          desc: "Max recovery session tokens a single IP may request per hour",
          allowed: Integer,
          default: 20

        add_composer :ip_send_hour,
          desc: "Max password reset sends a single IP may make per hour",
          allowed: Integer,
          default: 10
      end
    end
  end
end
