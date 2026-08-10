# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module SignupSession
      class RateLimits < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :jti_email,
          desc: "Max email availability lookups allowed for a single signup session (jti)",
          allowed: Integer,
          default: 50

        add_composer :jti_username,
          desc: "Max username availability lookups allowed for a single signup session (jti)",
          allowed: Integer,
          default: 50

        add_composer :jti_total,
          desc: "Max combined availability lookups allowed for a single signup session (jti)",
          allowed: Integer,
          default: 80

        add_composer :ip_issue_burst,
          desc: "Max signup session tokens a single IP may request per minute",
          allowed: Integer,
          default: 15

        add_composer :ip_issue_hour,
          desc: "Max signup session tokens a single IP may request per hour",
          allowed: Integer,
          default: 60

        add_composer :ip_availability_hour,
          desc: "Max availability lookups a single IP may make per hour",
          allowed: Integer,
          default: 200

        add_composer :ip_register_hour,
          desc: "Max registration attempts a single IP may make per hour",
          allowed: Integer,
          default: 20
      end
    end
  end
end
