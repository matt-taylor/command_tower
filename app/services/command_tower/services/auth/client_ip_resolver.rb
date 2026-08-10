# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      class ClientIpResolver
        def self.call(request:)
          request.remote_ip.to_s
        end
      end
    end
  end
end
