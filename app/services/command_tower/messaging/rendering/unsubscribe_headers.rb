# frozen_string_literal: true

require "cgi"

module CommandTower
  module Messaging
    module Rendering
      # RFC 8058 one-click headers for a defined-type email (design D21). Present only when the type
      # is not mandatory, is user configurable, allows email and `compliance.api_base_url` is set;
      # otherwise empty. The token is the only secret-bearing part and is never logged.
      module UnsubscribeHeaders
        POST_VALUE = "List-Unsubscribe=One-Click"

        class << self
          # @return [Boolean]
          def eligible?(declaration)
            !declaration.mandatory && declaration.user_configurable && declaration.allowed_channels.include?("email")
          end

          # One boot warning (type keys only) when eligible types exist but `compliance.api_base_url`
          # is unset, so their one-click headers are omitted.
          def warn_when_unconfigured(declarations)
            return if CommandTower.config.messaging.compliance.api_base_url.present?

            keys = declarations.select { |declaration| eligible?(declaration) }.map(&:key)
            return if keys.empty?

            Rails.logger.warn(
              "[command_tower] one-click unsubscribe headers omitted: config.messaging.compliance.api_base_url " \
              "is not set (types: #{keys.join(', ')})"
            )
          end

          # @return [Hash{String => String}]
          def call(declaration:, user_id:)
            base = CommandTower.config.messaging.compliance.api_base_url
            return {} if base.blank? || !eligible?(declaration)

            result = CommandTower::Services::Messaging::Unsubscribe::IssueToken.call(
              user_id:, notification_type_key: declaration.key
            )
            return {} unless result.success?

            url = "#{base}/messaging/unsubscribe?token=#{CGI.escape(result.data[:token])}"
            { "List-Unsubscribe" => "<#{url}>", "List-Unsubscribe-Post" => POST_VALUE }
          end
        end
      end
    end
  end
end
