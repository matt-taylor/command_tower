# frozen_string_literal: true

require "uri"

module CommandTower
  module Clients
    # URI-aware URL helpers for ClientBase absolutization.
    # Joins provider base_url with relative endpoint paths without URI.join
    # replacing intentional base path prefixes (e.g. /api/v1).
    module Url
      module_function

      def absolute?(url)
        uri = URI.parse(url.to_s)
        uri.absolute? && uri.host.present?
      rescue URI::InvalidURIError
        false
      end

      def join(base_url, relative_path)
        base = base_url.to_s.strip
        if base.empty?
          raise Errors::ConfigurationError, "base_url is required to resolve a relative request URL"
        end

        uri = URI.parse(base)
        unless uri.absolute? && uri.host.present?
          raise Errors::ConfigurationError,
                "base_url must be an absolute URL with a host (got: #{base_url.inspect})"
        end

        suffix = relative_path.to_s.delete_prefix("/")
        prefix = uri.path.to_s
        prefix = "" if prefix == "/"
        prefix = prefix.delete_suffix("/")

        combined = if prefix.empty?
                     "/#{suffix}"
        else
                     "#{prefix}/#{suffix}"
        end
        combined = "/" if combined.empty?

        result = uri.dup
        result.path = combined
        result.query = nil
        result.fragment = nil
        result.to_s
      rescue URI::InvalidURIError => e
        raise Errors::ConfigurationError,
              "invalid base_url: #{base_url.inspect}",
              cause: e
      end
    end
  end
end
