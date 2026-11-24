# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module Unsubscribe
        # RFC 8058 one-click unsubscribe: verify the signed token, turn email off for that user and
        # notification type, audit the first opt-out.
        #
        # Authorization sequence: none, by declaration. The caller is a mail client with no session;
        # the signed, purpose-bound, expiring token is the only credential and it names the one user
        # and one type it may change. Every failure is the same 422 body so the endpoint is not an oracle.
        class OneClickWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          Unsubscribes = CommandTower::Services::Messaging::Unsubscribe

          def call(token:, client_ip:)
            limited = Unsubscribes::CheckRateLimit.call(token:, client_ip:)
            return failure(errors: limited.errors, http_status: :too_many_requests) if limited.failure?

            verified = Unsubscribes::VerifyToken.call(token:)
            return failure(errors: verified.errors, http_status: :unprocessable_entity) if verified.failure?

            opt_out_and_audit(verified.data)
          end

          private

          def opt_out_and_audit(identity)
            opt_out = Unsubscribes::OptOutOfEmail.call(**identity.slice(:user_id, :notification_type_key))
            return failure(errors: opt_out.errors, http_status: status_for(opt_out.errors.first)) if opt_out.failure?

            audit_opt_out(opt_out.data[:user], identity[:notification_type_key]) if opt_out.data[:changed]
            success(payload: { unsubscribed: true }, http_status: :ok)
          end

          def status_for(error)
            error.is_a?(CommandTower::Errors::ValidationError) ? :unprocessable_entity : :internal_server_error
          end

          def audit_opt_out(user, notification_type_key)
            audit(
              :messaging_unsubscribed,
              subject: user,
              affected_user: user,
              attribution_mode: :system,
              changes: { email_enabled: { from: true, to: false } },
              metadata: { notification_type_key: }
            )
          end
        end
      end
    end
  end
end
