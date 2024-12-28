# frozen_string_literal: true

module ApiEngineBase::Username
  class Available < ApiEngineBase::ServiceBase
    on_argument_validation :fail_early

    REFRESH_KEY = "username.refresh_after"

    validate :username, is_a: String, required: true
    validate :force_query, is_a: [TrueClass, FalseClass]

    def initialize(*)
      super

      @mutex = Mutex.new
    end

    def call
      populate_local_cache! if refresh?

      context.available = available?
      context.valid = valid?
    end

    def valid?
      return false if username.length < ApiEngineBase.config.username.username_length_min
      return false if username.length > ApiEngineBase.config.username.username_length_max

      !!username[ApiEngineBase.config.username.username_regex]
    end

    def available?
      !realtime.local_cache.exist?(username)
    end

    # this is a very terrible cache design at scale
    # If we can use Redis, a bloom filter would be great
    def populate_local_cache!
      @mutex.synchronize do
        values = User.pluck(:username).map { [_1, 1] }.to_h rescue {}
        realtime.local_cache.write_multi(values)
        realtime.local_cache.write(REFRESH_KEY, realtime.local_cache_ttl.from_now)

        values
      end
    end

    def refresh?
      return true if force_query

      refresh_by = realtime.local_cache.read(REFRESH_KEY)
      return true if refresh_by.nil?

      time = Time.at(refresh_by) rescue nil
      return true if time.nil?

      time < Time.now
    end

    def realtime
      ApiEngineBase.config.username.realtime_username_check
    end
  end
end
