# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      # `email` and `password` are required. The old six-field shape stays accepted: names
      # default to "", `username` and `password_confirmation` are nil when not sent.
      class RegisterDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(
          :first_name,
          :last_name,
          :username,
          :email,
          :password,
          :password_confirmation,
          :start_session
        )

        def call(params)
          email = params[:email].to_s.strip.downcase
          password = params[:password].to_s

          return failure(errors: { message: "missing_required_fields" }) if email.blank? || password.blank?

          success(
            Input.new(
              first_name: params[:first_name].to_s.strip,
              last_name: params[:last_name].to_s.strip,
              username: params[:username].to_s.strip.presence,
              email:,
              password:,
              password_confirmation: params[:password_confirmation].presence&.to_s,
              start_session: ActiveModel::Type::Boolean.new.cast(params[:start_session]) == true
            )
          )
        end
      end
    end
  end
end
