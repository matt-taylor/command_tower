# frozen_string_literal: true

require "json"

module CommandTower
  module EmailTheme
    # Reads and validates the shared email token file (design D19). The host
    # file lives at a fixed path (`config/ui_tokens.json` under Rails.root) and
    # is written by the frontend export bin; CT ships a default file of its own.
    #
    # Format: { "version": 1, "palette": { "<token>": "#rrggbb", ... } }. The
    # palette carries every semantic token the app uses; CT only requires the
    # keys the email renderer reads (Palette::KEYS) and ignores the rest.
    # Parsed with JSON.parse only. Error messages name keys, never values.
    module TokenFile
      class InvalidError < CommandTower::Error; end

      SUPPORTED_VERSION = 1
      HEX_COLOR = /\A#\h{6}\z/
      DEFAULT_PATH = File.expand_path("default_ui_tokens.json", __dir__)
      HOST_RELATIVE_PATH = "config/ui_tokens.json"
      MISSING_FILE_WARNING = "[CommandTower] #{HOST_RELATIVE_PATH} not found; email uses config.email_theme " \
                             "or CommandTower's default palette. Export it with ct-export-email-tokens.".freeze

      class << self
        def host_path
          Rails.root.join(HOST_RELATIVE_PATH).to_s
        end

        def host_file?(path = host_path)
          File.file?(path)
        end

        # Returns the validated, frozen palette Hash (string keys, all tokens in the file).
        # Raises InvalidError when the file is unreadable, not JSON, or malformed.
        def load_palette(path)
          document = parse(path)
          raise InvalidError, "token file must be a JSON object" unless document.is_a?(Hash)
          unless document["version"] == SUPPORTED_VERSION
            raise InvalidError, "token file version must be #{SUPPORTED_VERSION}"
          end

          palette = document["palette"]
          raise InvalidError, "token file palette must be an object" unless palette.is_a?(Hash)

          validate_palette!(palette)
          palette.freeze
        end

        # Boot check. An invalid host file raises (boot error); a missing one
        # logs a single warning (0.23.0 keeps the file optional).
        def validate_host_file!(logger: Rails.logger)
          path = host_path
          if host_file?(path)
            load_palette(path)
          else
            logger&.warn(MISSING_FILE_WARNING)
          end
        end

        private

        def parse(path)
          JSON.parse(File.read(path))
        rescue JSON::ParserError
          raise InvalidError, "token file is not valid JSON"
        rescue SystemCallError
          raise InvalidError, "token file could not be read"
        end

        def validate_palette!(palette)
          missing = Palette::KEYS - palette.keys
          raise InvalidError, "token file palette missing keys: #{missing.join(', ')}" if missing.any?

          bad = palette.reject { |_key, value| value.is_a?(String) && HEX_COLOR.match?(value) }.keys
          raise InvalidError, "token file palette values must be #RRGGBB: #{bad.join(', ')}" if bad.any?
        end
      end
    end
  end
end
