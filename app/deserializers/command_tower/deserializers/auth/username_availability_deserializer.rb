# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      class UsernameAvailabilityDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:username)

        def call(params)
          username = params[:username].to_s.strip

          return failure(errors: { message: "missing_username" }) if username.blank?

          success(Input.new(username:))
        end
      end
    end
  end
end
