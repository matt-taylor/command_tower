# frozen_string_literal: true

module CommandTower
  module Clients
    module Transport
      Response = Data.define(:status, :headers, :body, :duration_ms) do
        def self.build(status:, headers: {}, body: nil, duration_ms: nil)
          new(
            status: Integer(status),
            headers: headers.to_h.transform_keys(&:to_s),
            body: body,
            duration_ms: duration_ms
          )
        end

        def success?
          status >= 200 && status < 300
        end
      end
    end
  end
end
