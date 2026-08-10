# frozen_string_literal: true

module CommandTower::Username
  # Realtime username validity + availability lookup backed by the configured
  # local cache. Shared by registration, admin/self-service attribute changes and
  # the availability endpoint, so it stays a plain domain object rather than a
  # capability service.
  class Available
    REFRESH_KEY = "username.refresh_after"

    CACHE_MUTEX = Mutex.new

    Availability = Data.define(:valid, :available) do
      def valid? = valid

      def available? = available
    end

    def self.call(username:, force_query: false)
      new(username:, force_query:).call
    end

    def initialize(username:, force_query: false)
      @username = username
      @force_query = force_query
    end

    def call
      populate_local_cache! if refresh?

      Availability.new(valid: valid?, available: available?)
    end

    private

    attr_reader :username, :force_query

    def valid?
      return false if username.length < CommandTower.config.username.username_length_min
      return false if username.length > CommandTower.config.username.username_length_max

      !!username[CommandTower.config.username.username_regex]
    end

    def available?
      !realtime.local_cache.exist?(username)
    end

    # this is a very terrible cache design at scale
    # If we can use Redis, a bloom filter would be great
    def populate_local_cache!
      CACHE_MUTEX.synchronize do
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
      CommandTower.config.username.realtime_username_check
    end
  end
end
