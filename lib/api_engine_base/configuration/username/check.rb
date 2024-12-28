# frozen_string_literal: true

require "class_composer"

module ApiEngineBase
  module Configuration
    module Username
      class Check
      include ClassComposer::Generator

        add_composer :enable,
          desc: "Enable Controller method for checking Real time username availability",
          allowed: [FalseClass, TrueClass],
          default: true

        add_composer :local_cache,
          desc: "Local Cache store. Instantiated before fork",
          allowed: [ActiveSupport::Cache::MemoryStore, ActiveSupport::Cache::FileStore],
          default: ActiveSupport::Cache::MemoryStore.new

        add_composer :local_cache_ttl,
          desc: "TTL on local cache data before data is invalidated and upstream is queried",
          allowed: ActiveSupport::Duration,
          default_shown: "1.minutes",
          default: 1.minute,
          validator: -> (val) { val < 60.minutes },
          invalid_message: ->(val) { "Provided #{val}. Value must be less than #{60.minutes}" }
      end
    end
  end
end
