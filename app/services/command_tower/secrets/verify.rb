# frozen_string_literal: true

module CommandTower::Secrets
  class Verify < CommandTower::ServiceBase
    validate :secret, is_a: String, required: true, sensitive: true
    validate :reason, is_one: ALLOWED_SECRET_REASONS, required: true
    validate :access_count, is_one: [true, false], default: false

    def call
      record = UserSecret.find_record(secret:, reason:, access_count:)

      if record[:found] == false
        context.fail!(record:, msg: "Secret not found")
      end

      if record[:valid] == false
        if CommandTower.config.delete_secret_after_invalid
          record[:record].destroy
        end

        context.fail!(record:, msg: "Secret is invalid. #{record[:record].invalid_reason.join(" ")}")
      end

      context.user = record[:user]
    end
  end
end
