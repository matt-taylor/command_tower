# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::EmailVerification
  # Decides whether an unverified account has passed its grace period and must
  # verify before it can keep authenticating.
  class Required
    Requirement = Data.define(:required, :required_after_time) do
      def required? = required
    end

    def self.call(user:)
      required_after_time = user.created_at + email_verify.verify_email_required_within

      Requirement.new(required: Time.now > required_after_time, required_after_time:)
    end

    def self.email_verify
      CommandTower.config.login.plain_text.email_verify
    end
    private_class_method :email_verify
  end
end
