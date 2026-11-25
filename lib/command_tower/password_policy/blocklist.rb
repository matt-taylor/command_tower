# frozen_string_literal: true

require "zlib"

module CommandTower
  module PasswordPolicy
    # Common-password blocklist. Loaded once per configured path list into a frozen Set and
    # reused; entries are compared case-insensitively. Files ending in `.gz` are gunzipped,
    # anything else is read as plain text (one password per line).
    module Blocklist
      DEFAULT_PATH = File.expand_path("../data/password-blocklist-100k.txt.gz", __dir__).freeze

      MUTEX = Mutex.new
      private_constant :MUTEX

      class << self
        def include?(password)
          entries.include?(normalize(password))
        end

        # Drops the memoized set so the next lookup reloads from the configured paths.
        def reset!
          MUTEX.synchronize { @entries = nil }
        end

        private

        def entries
          current = @entries
          return current if current

          MUTEX.synchronize { @entries ||= load_entries(CommandTower.config.login.plain_text.password_blocklist_paths) }
        end

        def load_entries(paths)
          set = Set.new
          Array(paths).each { |path| read_lines(path).each { |line| set << normalize(line) } }
          set.delete("")
          set.freeze
        end

        def read_lines(path)
          reader = path.to_s.end_with?(".gz") ? Zlib::GzipReader : File
          reader.open(path, &:readlines)
        end

        def normalize(value)
          value.to_s.strip.downcase
        end
      end
    end
  end
end
