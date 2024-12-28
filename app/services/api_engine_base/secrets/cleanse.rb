# frozen_string_literal: true

module ApiEngineBase::Secrets
  class Cleanse < ApiEngineBase::ServiceBase
    validate :user, is_a: User, required: true
    validate :reason, is_one: ALLOWED_SECRET_REASONS, required: true

    def call
      secrets = UserSecret.where(user:, reason:)
      count = secrets.delete_all
      log_info("Cleansed #{count} #{reason} secret(s) from the store for user [#{user.id}]")
    end
  end
end
