# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      class Recipients < CommandTower::Services::ApplicationService
        validate :user, is_a: User, required: true

        def call
          unless user.persisted? && user.id.present?
            context.fail!(application_error: CommandTower::Errors::Messaging::RecipientUnresolvedError.new)
            return
          end

          context.recipient_id = user.id
        end
      end
    end
  end
end
