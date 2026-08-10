# frozen_string_literal: true

module CommandTower::Secrets
  # Redeems a previously issued user secret. Called from capability services, so
  # it stays a plain domain object with a narrow outcome.
  class Verify
    NOT_FOUND_MSG = "Secret not found"

    class Redemption
      attr_reader :user, :record, :msg

      def self.success(user:, record:)
        new(success: true, user:, record:)
      end

      def self.failure(record:, msg:)
        new(success: false, record:, msg:)
      end

      def initialize(success:, user: nil, record: nil, msg: nil)
        @success = success
        @user = user
        @record = record
        @msg = msg
      end

      def success? = @success

      def failure? = !@success
    end

    def self.call(secret:, reason:, access_count: false)
      new(secret:, reason:, access_count:).call
    end

    def initialize(secret:, reason:, access_count: false)
      @secret = secret
      @reason = reason
      @access_count = access_count
    end

    def call
      record = UserSecret.find_record(secret:, reason:, access_count:)

      return Redemption.failure(record:, msg: NOT_FOUND_MSG) if record[:found] == false

      if record[:valid] == false
        reason_text = record[:record].invalid_reason.join(" ")
        record[:record].destroy if CommandTower.config.delete_secret_after_invalid

        return Redemption.failure(record:, msg: "Secret is invalid. #{reason_text}")
      end

      Redemption.success(user: record[:user], record:)
    end

    private

    attr_reader :secret, :reason, :access_count
  end
end
