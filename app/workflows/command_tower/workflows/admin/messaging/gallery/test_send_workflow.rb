# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Messaging
        module Gallery
          # Sends one gallery fixture as an email to the real actor's own address, through the
          # existing adapter boundary (`SelectAdapter`: the fake adapter when enabled, else the
          # configured email adapter). Authorization is the controller's RBAC boundary (entity
          # `admin_messaging_gallery_test_send`).
          #
          # - Refused with `gallery_test_send_impersonating` (403) while impersonating or when the
          #   actor is not the effective user.
          # - Rate limited per real actor (see `CheckTestSendRateLimit`); a Redis error fails closed.
          # - Creates no `Communication`. Audits `messaging_gallery_test_sent` with ids and the type
          #   key only, never the address.
          class TestSendWorkflow < CommandTower::Workflows::ApplicationWorkflow
            retry_strategy :none

            Delivery = Data.define(:channel_key)

            def call(actor:, effective_user:, notification_type_key:, fixture: nil, zone: nil)
              return refuse_impersonation if impersonating?(actor, effective_user)

              built = CommandTower::Services::Messaging::Gallery::TestSend.call(
                notification_type_key:, fixture:, zone:, actor:
              )
              return failed(built) unless built.success?

              limit = CommandTower::Services::Messaging::Gallery::CheckTestSendRateLimit.call(actor_id: actor.id)
              return failed(limit) unless limit.success?

              send_and_audit(built.data, actor:, notification_type_key:, fixture:)
            end

            private

            def send_and_audit(data, actor:, notification_type_key:, fixture:)
              outcome = deliver(data)
              return failed_delivery(outcome) unless outcome.success?

              audit_sent(actor:, notification_type_key:, fixture:)
              success(
                payload: { "notificationTypeKey" => notification_type_key, "sent" => true }, http_status: :accepted
              )
            end

            def impersonating?(actor, effective_user)
              CommandTower::Current.impersonation_active == true || actor.id != effective_user.id
            end

            def refuse_impersonation
              failure(
                errors: [CommandTower::Errors::Messaging::GalleryTestSendImpersonatingError.new],
                http_status: :forbidden
              )
            end

            def deliver(data)
              delivery = Delivery.new(channel_key: "email")
              CommandTower::Messaging::Execution::SelectAdapter.call(delivery:).call(request: adapter_request(data))
            end

            def adapter_request(data)
              content = data[:content]
              rendered = CommandTower::Messaging::Rendering::RenderedPayload.build(
                recipient_address: data[:recipient], subject: content[:subject],
                text_body: content[:text], html_body: content[:html]
              )
              id = "gallery-test-#{SecureRandom.uuid}"
              CommandTower::Messaging::Execution::AdapterRequest.build(
                channel_delivery_id: id, communication_id: id, channel_key: "email", attempt_id: id, rendered:
              )
            end

            def audit_sent(actor:, notification_type_key:, fixture:)
              audit(
                :messaging_gallery_test_sent,
                affected_user: actor,
                changes: {},
                metadata: { actor_id: actor.id, notification_type_key:, fixture: }.compact,
                attribution_mode: :self_service
              )
            end

            def failed(result)
              failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Messaging::ErrorMapping.http_status_for(result.errors.first)
              )
            end

            def failed_delivery(outcome)
              error = CommandTower::Errors::Messaging::GalleryTestSendFailedError.new(error_code: outcome.error_code)
              failure(errors: [error], http_status: :bad_gateway)
            end
          end
        end
      end
    end
  end
end
