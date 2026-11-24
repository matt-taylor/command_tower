# frozen_string_literal: true

module CommandTower
  module Execution
    module HttpBoundary
      extend ActiveSupport::Concern

      CLIENT_TIME_ZONE_MAX_LENGTH = 64

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
          user_agent: request.user_agent,
          ui_catalog: CommandTower::UI::Catalog.from_header(request.headers["X-UI-Catalog"]),
          client_time_zone: parse_client_time_zone(request.headers["X-Time-Zone"])
        ) do
          yield
          record_impersonation_activity_if_needed
          record_client_time_zone_if_needed
        end
      end

      # A TZInfo identifier of at most 64 characters, else nil (the header is ignored).
      def parse_client_time_zone(raw)
        zone = raw.to_s.strip
        return nil if zone.empty? || zone.length > CLIENT_TIME_ZONE_MAX_LENGTH

        zone if TZInfo::Timezone.all_identifiers.include?(zone)
      end

      # Request bookkeeping that runs outside a workflow, like impersonation activity above: it is
      # a throttled side write on the authenticated user, not a business operation, and it must
      # never change the response.
      def record_client_time_zone_if_needed
        zone = CommandTower::Current.client_time_zone
        return if zone.blank? || !response.status.to_i.between?(200, 299)

        user = time_zone_recordable_user
        CommandTower::Services::Users::RecordLastKnownTimeZone.call(user:, zone:) if user
      rescue StandardError
        nil
      end

      # The real authenticated actor, taken from the authentication result (there is no
      # Current.user). Impersonated requests return nil so an admin's zone never lands on the target.
      def time_zone_recordable_user
        return if CommandTower::Current.impersonation_active

        auth_context = try(:current_auth_context)
        user = auth_context&.user
        user if user && auth_context.actor_user&.id == user.id
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
