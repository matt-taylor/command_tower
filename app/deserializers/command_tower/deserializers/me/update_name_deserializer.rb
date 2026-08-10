# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      class UpdateNameDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:first_name, :last_name)

        def call(params)
          first_name = (params[:first_name] || params[:firstName]).to_s.strip
          last_name = (params[:last_name] || params[:lastName]).to_s.strip

          if first_name.blank? || last_name.blank?
            return failure(errors: { message: "missing_required_fields" })
          end

          success(Input.new(first_name:, last_name:))
        end
      end
    end
  end
end
