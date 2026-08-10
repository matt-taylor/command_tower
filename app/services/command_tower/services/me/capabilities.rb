# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Projects which Account self-service actions are enabled for the current user.
      class Capabilities
        def self.project(user)
          new(user).project
        end

        def initialize(user)
          @user = user
        end

        def project
          {
            editName: { enabled: true },
            editUsername: { enabled: false },
            changeEmail: { enabled: false },
            changePassword: { enabled: true },
            editPhone: { enabled: sms_enabled? },
            editPushover: { enabled: pushover_enabled? },
            logoutAllDevices: { enabled: false },
            verifyEmail: { enabled: !user.email_validated }
          }
        end

        private

        attr_reader :user

        def sms_enabled?
          CommandTower::Messaging::ChannelDetectors.sms_product_ready?
        end

        def pushover_enabled?
          CommandTower::Messaging::ChannelDetectors.pushover_configured?
        end
      end
    end
  end
end
