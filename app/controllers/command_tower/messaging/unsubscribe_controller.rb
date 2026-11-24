# frozen_string_literal: true

module CommandTower
  module Messaging
    # One-click unsubscribe (RFC 8058). Unauthenticated by design: the caller is a mail client.
    #
    # - It never authenticates and never reads the session or cookies. `ActionController::API` has no
    #   cookie CSRF protection, and `authenticate_user!` (the only CSRF check) is not called, so a
    #   cookie-bearing request is treated like any other.
    # - The only credential is the signed token in the query string (`token` is a filtered parameter).
    # - Responses are `no-store` with `Referrer-Policy: no-referrer`, so the token is not cached or
    #   leaked in a Referer header.
    # - Rate limits key mainly on the token digest. The per-IP limit uses `request.remote_ip`, which
    #   follows `X-Forwarded-For` only behind the host's `trusted_proxies`.
    # - `show` (GET) is a documented transport non-envelope: a 303 redirect to the preferences page,
    #   since a person's browser follows it. It never mutates.
    class UnsubscribeController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      before_action :set_privacy_headers

      def show
        result = CommandTower::Workflows::Messaging::Unsubscribe::PreferencesRedirectWorkflow.call
        redirect_to result.payload[:location], status: :see_other, allow_other_host: true
      end

      def create
        result = CommandTower::Workflows::Messaging::Unsubscribe::OneClickWorkflow.call(
          token: params[:token].to_s,
          client_ip: CommandTower::Services::Auth::ClientIpResolver.call(request:)
        )
        render_application_result(result)
      end

      private

      def set_privacy_headers
        response.set_header("Referrer-Policy", "no-referrer")
        response.set_header("Cache-Control", "no-store")
      end
    end
  end
end
