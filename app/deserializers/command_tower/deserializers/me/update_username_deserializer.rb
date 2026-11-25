# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      class UpdateUsernameDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:username)

        def call(params)
          username = params[:username]
          return failure(errors: { message: "missing_required_fields" }) unless username.is_a?(String)

          username = username.strip
          return failure(errors: { message: "missing_required_fields" }) if username.empty?

          success(Input.new(username:))
        end
      end
    end
  end
end
