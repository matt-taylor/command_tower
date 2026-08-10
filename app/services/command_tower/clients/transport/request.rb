# frozen_string_literal: true

module CommandTower
  module Clients
    module Transport
      Request = Data.define(:method, :url, :headers, :body, :query, :timeout) do
        SUPPORTED_METHODS = %i[get post put patch delete].freeze

        def self.build(method:, url:, headers: {}, body: nil, query: {}, timeout: nil)
          new(
            method: normalize_and_validate_method(method),
            url: url.to_s,
            headers: normalize_headers(headers),
            body: body,
            query: normalize_query(query),
            timeout: timeout
          )
        end

        def self.validate_method!(method)
          normalize_and_validate_method(method)
        end

        def self.normalize_and_validate_method(method)
          normalized = method.to_s.downcase.to_sym
          return normalized if SUPPORTED_METHODS.include?(normalized)

          raise Errors::ConfigurationError,
                "unsupported HTTP method: #{method.inspect} " \
                "(supported: #{SUPPORTED_METHODS.join(', ')})"
        end
        private_class_method :normalize_and_validate_method

        def self.normalize_headers(headers)
          headers.to_h.transform_keys(&:to_s)
        end
        private_class_method :normalize_headers

        def self.normalize_query(query)
          query.to_h.transform_keys(&:to_s)
        end
        private_class_method :normalize_query

        def merge_headers(extra)
          with(headers: headers.merge(self.class.send(:normalize_headers, extra)))
        end
      end
    end
  end
end
