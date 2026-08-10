# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      class RegisterDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(
          :first_name,
          :last_name,
          :username,
          :email,
          :password,
          :password_confirmation
        )

        def call(params)
          first_name = params[:first_name].to_s.strip
          last_name = params[:last_name].to_s.strip
          username = params[:username].to_s.strip
          email = params[:email].to_s.strip.downcase
          password = params[:password].to_s
          password_confirmation = params[:password_confirmation].to_s

          if [first_name, last_name, username, email, password, password_confirmation].any?(&:blank?)
            return failure(errors: { message: "missing_required_fields" })
          end

          success(
            Input.new(
              first_name:,
              last_name:,
              username:,
              email:,
              password:,
              password_confirmation:
            )
          )
        end
      end
    end
  end
end
