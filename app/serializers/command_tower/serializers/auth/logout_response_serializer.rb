# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class LogoutResponseSerializer
        def self.serialize
          { message: "logged_out" }
        end
      end
    end
  end
end
