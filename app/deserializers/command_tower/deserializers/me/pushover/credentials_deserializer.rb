# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      module Pushover
        class CredentialsDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:user_key, :application_token)

          def call(params)
            user_key = extract(params, :user_key, :userKey)
            application_token = extract(params, :application_token, :applicationToken)

            if user_key.blank? || application_token.blank?
              return failure(errors: { message: "missing_required_fields" })
            end

            success(Input.new(user_key:, application_token:))
          end

          private

          def extract(params, snake, camel)
            raw = params[snake] || params[camel]
            raw.nil? ? "" : raw.to_s.strip
          end
        end
      end
    end
  end
end
