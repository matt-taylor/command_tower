# frozen_string_literal: true

module CommandTower::Secrets
  class Generate < CommandTower::ServiceBase
    MAX_RETRY = 10

    validate :user, is_a: User, required: true
    validate :secret_length, is_a: Integer, gte: 4, lte: 64, required: true
    validate :reason, is_one: ALLOWED_SECRET_REASONS, required: true
    validate :type, is_one: ALLOWED_SECRET_TYPES, default: DEFAULT_SECRET_TYPE
    validate :extra, is_a: String, length: true, lt: 256
    validate :cleanse, is_one: [true, false], default: false
    at_least_one(:death, required: true) do
      validate :death_time, is_a: ActiveSupport::Duration, gte: 10.seconds
      validate :use_count_max, is_a: Integer, gte: 1
    end

    def call
      if cleanse && @attempts.nil?
        # if this fails ... so be it
        Cleanse.(user:, reason:)
      end

      @attempts ||= 1
      record = UserSecret.create!(**db_params)

      context.record = record
      context.secret = record.secret
    rescue ActiveRecord::RecordNotUnique => e
      if @attempts < MAX_RETRY
        @attempts += 1
        log_warn("Duplicate Secret was generated. Attempting to retry: #{@attempts} of #{MAX_RETRY}")
        retry
      else
        log_error("Duplicate Secret was generated. Exhausted Max attempts of #{MAX_RETRY}.")
        context.fail!(msg: "Failed to generate Secret. Cannot Continue")
      end
    end

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
  end
end
