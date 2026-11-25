# frozen_string_literal: true

module CommandTower
  module Deserializers
    module HomeNotices
      # Reads the `:id` of a home-notice mutation: a row `public_id` or `campaign:<key>`.
      # The result carries exactly one of `public_id` and `campaign_key`.
      class NoticeIdDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        CAMPAIGN_PREFIX = "campaign:"
        PUBLIC_ID_FORMAT = /\A[A-Za-z0-9]{1,32}\z/
        CAMPAIGN_KEY_FORMAT = /\A[a-z0-9_]+(\.[a-z0-9_]+)+\z/

        Input = Data.define(:public_id, :campaign_key)

        def call(params)
          raw = unwrap(require_string(fetch_param(params, :id).value, field: :id))
          return raw if deserializer_result?(raw)

          raw.start_with?(CAMPAIGN_PREFIX) ? campaign_input(raw.delete_prefix(CAMPAIGN_PREFIX)) : public_id_input(raw)
        end

        private

        def campaign_input(key)
          return invalid unless CAMPAIGN_KEY_FORMAT.match?(key)

          success(Input.new(public_id: nil, campaign_key: key))
        end

        def public_id_input(value)
          return invalid unless PUBLIC_ID_FORMAT.match?(value)

          success(Input.new(public_id: value, campaign_key: nil))
        end

        def invalid
          failure(errors: CommandTower::Deserializers::Failure.build(code: "invalid_value", field: :id))
        end
      end
    end
  end
end
