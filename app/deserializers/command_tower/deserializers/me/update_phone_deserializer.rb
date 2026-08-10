# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      class UpdatePhoneDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:phone_number)

        def call(params)
          raw = params[:phone_number] || params[:phoneNumber]
          phone_number = raw.nil? ? "" : raw.to_s

          if phone_number.strip.blank?
            return failure(errors: { message: "missing_required_fields" })
          end

          success(Input.new(phone_number:))
        end
      end
    end
  end
end
