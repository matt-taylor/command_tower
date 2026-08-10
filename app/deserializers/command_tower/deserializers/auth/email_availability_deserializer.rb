# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      class EmailAvailabilityDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:email)

        def call(params)
          email = params[:email].to_s.strip.downcase

          return failure(errors: { message: "missing_email" }) if email.blank?

          success(Input.new(email:))
        end
      end
    end
  end
end
