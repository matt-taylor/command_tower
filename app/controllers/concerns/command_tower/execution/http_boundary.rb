# frozen_string_literal: true

module CommandTower
  module Execution
    module HttpBoundary
      extend ActiveSupport::Concern

      included do
        around_action :command_tower_http_execution
      end

      private

      def command_tower_http_execution
        request_id = request.request_id.presence || request.uuid
        CommandTower.with_execution(
          source: :http,
          request_id:,
          correlation_id: request_id,
          remote_ip: request.remote_ip,
          user_agent: request.user_agent
        ) do
          yield
          record_impersonation_activity_if_needed
        end
      end

      def record_impersonation_activity_if_needed
        return unless CommandTower::Current.impersonation_active
        return unless CommandTower::Current.impersonation_activity_recorded
        return unless response.status.to_i.between?(200, 299)

        session_id = CommandTower::Current.impersonation_session_id
        return if session_id.blank?

        result = CommandTower::Services::Impersonation::RecordActivity.call(session_id:)
        return unless result.success?
        return unless result.data[:refreshed]

        merge_impersonation_clock_meta!(result.data[:session])
      end

      def merge_impersonation_clock_meta!(session)
        return if session.nil?

        raw = response.body
        return if raw.blank?

        parsed = JSON.parse(raw)
        return unless parsed.is_a?(Hash)

        parsed["meta"] ||= {}
        parsed["meta"]["impersonation"] = {
          "idleExpiresAt" => CommandTower::Serializers::ApplicationSerializer.iso8601(session.idle_expires_at),
          "absoluteExpiresAt" => CommandTower::Serializers::ApplicationSerializer.iso8601(session.absolute_expires_at)
        }
        json = parsed.to_json
        response.body = json
        response.headers["Content-Length"] = json.bytesize.to_s
      rescue JSON::ParserError
        nil
      end
    end
  end
end
