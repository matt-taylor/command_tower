# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Admin
      module Messaging
        class CreateAnnouncementDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(
            :title,
            :body,
            :notification_type_key,
            :campaign_identity,
            :audience,
            :user_ids,
            :execution_mode,
            :metadata
          )

          ALLOWED_AUDIENCES = %w[user_ids all_users].freeze
          ALLOWED_EXECUTION_MODES = %w[async sync].freeze

          def call(params)
            raw = normalize_hash(params)
            return failure(errors: { base: "invalid_request" }) if raw.nil?

            title = require_non_blank_string(raw, "title")
            return title if deserializer_result?(title)

            body = require_non_blank_string(raw, "body")
            return body if deserializer_result?(body)

            notification_type_key = optional_string(raw, "notificationTypeKey") || "promotional_announcement"
            campaign_identity = require_non_blank_string(raw, "campaignIdentity")
            return campaign_identity if deserializer_result?(campaign_identity)

            audience = require_non_blank_string(raw, "audience")
            return audience if deserializer_result?(audience)
            return failure(errors: { audience: "must be user_ids or all_users" }) unless ALLOWED_AUDIENCES.include?(audience)

            user_ids = Array(raw["userIds"] || raw["user_ids"])
            if audience == "user_ids"
              return failure(errors: { userIds: "required when audience is user_ids" }) if user_ids.empty?

              begin
                user_ids = user_ids.map { |id| Integer(id) }
              rescue ArgumentError, TypeError
                return failure(errors: { userIds: "must be integers" })
              end
            else
              user_ids = []
            end

            execution_mode = optional_string(raw, "executionMode") || "async"
            return failure(errors: { executionMode: "must be async or sync" }) unless ALLOWED_EXECUTION_MODES.include?(execution_mode)

            metadata = raw["metadata"]
            return failure(errors: { metadata: "must be an object" }) if !metadata.nil? && !metadata.is_a?(Hash)

            success(
              Input.new(
                title:,
                body:,
                notification_type_key:,
                campaign_identity:,
                audience: audience.to_sym,
                user_ids:,
                execution_mode: execution_mode.to_sym,
                metadata:,
              )
            )
          end

          private

          def normalize_hash(params)
            hash =
              if params.respond_to?(:to_unsafe_h)
                params.to_unsafe_h
              elsif params.respond_to?(:to_h)
                params.to_h
              else
                return nil
              end

            hash.transform_keys(&:to_s)
          end

          def require_non_blank_string(raw, key)
            value = raw[key] || raw[key.underscore]
            return failure(errors: { key => "is required" }) if value.nil? || !value.is_a?(String) || value.strip.empty?

            value.strip
          end

          def optional_string(raw, key)
            value = raw[key] || raw[key.underscore]
            return nil if value.nil?
            return nil unless value.is_a?(String)

            value.strip.presence
          end
        end
      end
    end
  end
end
