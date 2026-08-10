# frozen_string_literal: true

module CommandTower::Secrets
  # Issues a single-purpose user secret (email verification, password reset,
  # phone verification). Called from capability services, so it stays a plain
  # domain object with a narrow outcome.
  class Generate
    include CommandTower::ServiceLogging

    MAX_RETRY = 10
    EXHAUSTED_MSG = "Failed to generate Secret. Cannot Continue"

    class Issued
      attr_reader :record, :secret, :msg

      def self.success(record:)
        new(success: true, record:, secret: record.secret)
      end

      def self.failure(msg:)
        new(success: false, msg:)
      end

      def initialize(success:, record: nil, secret: nil, msg: nil)
        @success = success
        @record = record
        @secret = secret
        @msg = msg
      end

      def success? = @success

      def failure? = !@success
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(user:, secret_length:, reason:, type: DEFAULT_SECRET_TYPE, extra: nil, cleanse: false, death_time: nil, use_count_max: nil)
      @user = user
      @secret_length = secret_length
      @reason = reason
      @type = type || DEFAULT_SECRET_TYPE
      @extra = extra
      @cleanse = !!cleanse
      @death_time = death_time
      @use_count_max = use_count_max
    end

    def call
      if cleanse && @attempts.nil?
        # if this fails ... so be it
        Cleanse.(user:, reason:)
      end

      @attempts ||= 1

      Issued.success(record: UserSecret.create!(**db_params))
    rescue ActiveRecord::RecordNotUnique
      if @attempts < MAX_RETRY
        @attempts += 1
        log_warn("Duplicate Secret was generated. Attempting to retry: #{@attempts} of #{MAX_RETRY}")
        retry
      end

      log_error("Duplicate Secret was generated. Exhausted Max attempts of #{MAX_RETRY}.")
      Issued.failure(msg: EXHAUSTED_MSG)
    end

    def generate_secret
      case type
      when :numeric
        secret_length.times.map { SecureRandom.rand(0...10) }.join
      when :alphanumeric, :hex
        SecureRandom.public_send(type, secret_length)
      when :uuid
        SecureRandom.public_send(type)
      end
    end

    private

    attr_reader :user, :secret_length, :reason, :type, :extra, :cleanse, :death_time, :use_count_max

    def db_params
      {
        death_time: death_time&.from_now,
        use_count_max:,
        extra:,
        reason:,
        secret: generate_secret,
        user:,
      }.compact
    end
  end
end
