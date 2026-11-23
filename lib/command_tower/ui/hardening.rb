# frozen_string_literal: true

require "uri"

module CommandTower
  module UI
    # Wire hardening for paths and links (design section 8.1). Every check
    # returns a code symbol or nil/true; none echoes the value it rejected.
    # Cases are shared with the frontend through spec/fixtures/ui/wire_hardening.json.
    module Hardening
      INTERNAL_PATH = %r{\A/(?![/\\])[^\s\\]*\z}
      CONTROL_OR_SPACE = /[[:cntrl:][:space:]]/
      # Encoded protocol-relative (%2f%2f, or a leading %2f), encoded backslash, encoded control characters.
      ENCODED_UNSAFE = %r{%2f%2f|%5c|\A/%2f|%[01][0-9a-f]|%7f}i
      UNSAFE_LINK_CHARS = /[[:cntrl:][:space:]\\]/
      MAILTO = /\Amailto:[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}(?:\?[^\s#]*)?\z/
      TEL = /\Atel:\+?[0-9][0-9.\-()]{2,19}\z/

      class << self
        def internal_path?(value)
          value.is_a?(String) &&
            INTERNAL_PATH.match?(value) &&
            !CONTROL_OR_SPACE.match?(value) &&
            !ENCODED_UNSAFE.match?(value)
        end

        # nil when the href is allowed; otherwise :invalid_href, :unsafe_scheme or :userinfo.
        def external_href_code(value)
          return :invalid_href unless plain_link_string?(value)

          case value
          when /\Ahttps:/ then https_code(value)
          when /\Amailto:/ then pattern_code(value, MAILTO)
          when /\Atel:/ then pattern_code(value, TEL)
          else :unsafe_scheme
          end
        end

        # Images: https only and the host must be an exact member of hosts
        # (already lowercased and IDN-normalized by config.ui).
        def image_src_code(value, hosts:)
          return :unsafe_scheme unless value.is_a?(String) && value.start_with?("https:")

          code = external_href_code(value)
          return code if code

          host = Hostname.normalize(URI.parse(value).host)
          hosts.include?(host) ? nil : :host_not_allowed
        end

        private

        def plain_link_string?(value)
          value.is_a?(String) && !value.empty? && !UNSAFE_LINK_CHARS.match?(value)
        end

        def pattern_code(value, pattern)
          pattern.match?(value) ? nil : :invalid_href
        end

        def https_code(value)
          uri = URI.parse(value)
          return :invalid_href unless uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty?
          return :userinfo if uri.userinfo

          nil
        rescue URI::InvalidURIError
          :invalid_href
        end
      end
    end
  end
end
