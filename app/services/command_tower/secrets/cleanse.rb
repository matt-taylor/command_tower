# frozen_string_literal: true

module CommandTower::Secrets
  # Drops every outstanding secret a user holds for one reason.
  class Cleanse
    include CommandTower::ServiceLogging

    def self.call(user:, reason:)
      new(user:, reason:).call
    end

    def initialize(user:, reason:)
      @user = user
      @reason = reason
    end

    def call
      count = UserSecret.where(user:, reason:).delete_all
      log_info("Cleansed #{count} #{reason} secret(s) from the store for user [#{user.id}]")

      count
    end

    private

    attr_reader :user, :reason
  end
end
