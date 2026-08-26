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
            editName: { enabled: !user.deleted? },
            editUsername: { enabled: false },
            changeEmail: { enabled: false },
            changePassword: { enabled: !user.deleted? },
            editPhone: { enabled: sms_enabled? && !user.deleted? },
            editPushover: { enabled: pushover_enabled? && !user.deleted? },
            logoutAllDevices: { enabled: false },
            verifyEmail: { enabled: !user.deleted? && !user.email_validated },
            deleteAccount: { enabled: !user.deleted? }
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
