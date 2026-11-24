# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Unsubscribe
        # GET on the unsubscribe URL (a person clicking the link, or a scanner prefetching it). It
        # never reads or verifies the token and never mutates: it only names where the preferences
        # page is, so the Location carries no token and no user id.
        #
        # Authorization sequence: none, by declaration. The result is the same public URL for everyone.
        class PreferencesRedirectWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call
            base = CommandTower.config.application.composed_url.to_s
            path = CommandTower.config.messaging.compliance.preferences_path.to_s
            success(payload: { location: "#{base}#{path}" }, http_status: :see_other)
          end
        end
      end
    end
  end
end
