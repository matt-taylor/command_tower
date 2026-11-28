# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module ErrorMapping
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::ValidationError,
               CommandTower::Errors::Messaging::RecipientUnresolvedError,
               CommandTower::Errors::Messaging::AcceptRejectedError,
               CommandTower::Errors::Messaging::AnnouncementTypeNotSupportedError
            :unprocessable_entity
          when CommandTower::Errors::Messaging::IdempotencyConflictError
            :conflict
          when CommandTower::Errors::NotFoundError
            :not_found
          when CommandTower::Errors::Messaging::GalleryTestSendImpersonatingError,
               CommandTower::Errors::Messaging::InboxImpersonationForbiddenError
            :forbidden
          when CommandTower::Errors::Messaging::GalleryTestSendRateLimitError
            :too_many_requests
          when CommandTower::Errors::Messaging::GalleryTestSendFailedError
            :bad_gateway
          else
            :internal_server_error
          end
        end
      end
    end
  end
end
