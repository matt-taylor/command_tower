# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      module Push
        class TokenDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:address)

          EXPO_TOKEN = CommandTower::Messaging::Endpoints::Validators::Push::EXPO_TOKEN

          def call(params)
            address = extract(params, :token, :Token, :address, :Address)

            if address.blank?
              return failure(errors: { message: "missing_required_fields" })
            end

            unless address.match?(EXPO_TOKEN)
              return failure(errors: { message: "invalid_push_token" })
            end

            success(Input.new(address:))
          end

          private

          def extract(params, *keys)
            keys.each do |key|
              raw = params[key] || params[key.to_s]
              next if raw.nil?

              value = raw.to_s.strip
              return value unless value.empty?
            end
            ""
          end
        end
      end
    end
  end
end
