# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      # The admin announcement endpoint targeted a type whose MessageDefinition is not an
      # AnnouncementDefinition (design D26).
      class AnnouncementTypeNotSupportedError < CommandTower::Errors::ApplicationError
        def code
          "announcement_type_not_supported"
        end

        def message
          "This notification type cannot be used for announcements"
        end

        def log_level
          :warn
        end
      end
    end
  end
end
