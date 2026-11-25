# frozen_string_literal: true

module CommandTower
  module Services
    module Me
      # Decides whether a user may set or change their own username.
      # Gated by the host flags `username.self_service` (set) and `username.self_change` (change an existing one).
      class UsernameChangeEligibility
        def self.eligible?(user)
          new(user).eligible?
        end

        def initialize(user)
          @user = user
        end

        def eligible?
          return false if user.deleted?
          return false unless config.self_service

          user.username.blank? || config.self_change
        end

        private

        attr_reader :user

        def config
          CommandTower.config.username
        end
      end
    end
  end
end
